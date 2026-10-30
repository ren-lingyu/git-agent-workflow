{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Gaw.Cli (main) where

import Control.Exception (try)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.FileEmbed (embedFile)
import Data.Version (showVersion)
import Gaw.Application.Auxiliary (initializeAuxiliary, renderAuxiliaryError)
import Gaw.Application.AuxiliaryCheck (inspectAuxiliary)
import Gaw.Application.Branch (deleteBranch, renameBranch, renderBranchError)
import Gaw.Application.Check (inspectBranchCheck, inspectCheck)
import Gaw.Application.Commit (createCommit)
import Gaw.Application.Deploy (deploy, deployAuxiliary, renderDeployError)
import Gaw.Application.Hook (evaluateTransaction)
import Gaw.Application.Init (initializeWithConfig, renderInitError)
import Gaw.Application.Status (StatusError (..), inspectStatus)
import Gaw.Application.Undeploy (UndeployError (..), undeploy)
import Gaw.Protocol.Auxiliary (auxiliaryValid, renderAuxiliaryReport)
import Gaw.Protocol.Branch (branchWarnings)
import Gaw.Protocol.Check (checkReady, renderBranchCheckReport, renderCheckReport)
import Gaw.Protocol.Commit (CommitRequest (..), renderCommitError)
import Gaw.Protocol.Deploy (DeployMode (..), deployedMode, renderDeployResult)
import Gaw.Protocol.Hook (HookError (..), HookPhase (..), parseHookPhase)
import Gaw.Protocol.Init (InitConfig (..), InitResult (..))
import Gaw.Protocol.Ref (objectIdBytes, parseSourceRef)
import Gaw.Protocol.Show (ShowError (..), prepareShowArguments)
import Gaw.Protocol.Status (renderStatusReport, statusHealthy)
import Gaw.Protocol.Undeploy (renderUndeployResult, residuals)
import Gaw.System.Clock (posixClock)
import Gaw.System.Entropy (secureUuidV4)
import Gaw.System.ExternalGit (gitExecutable)
import Gaw.System.FileSystem (posixFileSystem, readPosixFile)
import Gaw.System.Git (Git (..), GitInvocation (..), GitResult (..), runGitPosix)
import qualified Paths_git_agent_workflow as Package
import System.Exit (ExitCode (..), exitWith)
import System.IO (stderr, stdin, stdout)
import System.IO.Error (isDoesNotExistError)
import qualified System.OsString.Posix as OS
import qualified System.Posix.Directory.ByteString as Directory
import qualified System.Posix.Env.ByteString as Env

version :: BS.ByteString
version = BS.concat ["git-gaw ", BSC.pack (showVersion Package.version), "\n"]

helpText :: BS.ByteString -> Maybe BS.ByteString
helpText topic = case topic of
    "aux" -> Just $(embedFile "resources/help/aux.txt")
    "overview" -> Just $(embedFile "resources/help/overview.txt")
    "config" -> Just $(embedFile "resources/help/config.txt")
    "commit" -> Just $(embedFile "resources/help/commit.txt")
    "show" -> Just $(embedFile "resources/help/show.txt")
    "check" -> Just $(embedFile "resources/help/check.txt")
    "status" -> Just $(embedFile "resources/help/status.txt")
    "deploy" -> Just $(embedFile "resources/help/deploy.txt")
    "undeploy" -> Just $(embedFile "resources/help/undeploy.txt")
    "init" -> Just $(embedFile "resources/help/init.txt")
    "branch" -> Just $(embedFile "resources/help/branch.txt")
    "hooks" -> Just $(embedFile "resources/help/hooks.txt")
    "recovery" -> Just $(embedFile "resources/help/recovery.txt")
    _ -> Nothing

run :: [BS.ByteString] -> IO ExitCode
run args = case args of
    "--reference-transaction" : phases -> runHook phases
    ["--version"] -> BS.hPut stdout version >> pure ExitSuccess
    ["version"] -> BS.hPut stdout version >> pure ExitSuccess
    ["--help"] -> printHelp "overview"
    ["-h"] -> printHelp "overview"
    ["help"] -> printHelp "overview"
    ["help", topic]
        | topic == "overview" -> unknownHelp topic
        | otherwise -> printHelp topic
    [command, "--help"] | command `elem` helpCommands -> printHelp command
    "aux" : options -> runAuxiliary options
    "show" : options -> runShow options
    "check" : options -> runCheck options
    "status" : options -> runStatus options
    "commit" : options -> runCommit options
    "deploy" : options -> runDeploy options
    "branch" : options -> runBranch options
    "init" : options -> runInit options
    "undeploy" : options -> runUndeploy options
    _ -> BS.hPut stderr usageText >> pure (ExitFailure 1)
  where
    helpCommands = ["aux", "commit", "show", "check", "status", "deploy", "undeploy", "init", "branch"]

usageText :: BS.ByteString
usageText =
    BS.concat
        [ "git-gaw: Usage:\n"
        , "  git gaw aux init [--worktree-path <path>] | deploy --branch <name> [--worktree-path <path>] | check [--branch <name>]\n"
        , "  git gaw init --branch <name> [--worktree-path <path>] [--use-default-config]\n"
        , "  git gaw deploy [--branch <name>] [--worktree-path <path>]\n"
        , "  git gaw undeploy\n"
        , "  git gaw branch -m <new-name> | -d <name> | -D <name>\n"
        , "  git gaw commit [options] [--] [project-commit...]\n"
        , "  git gaw show [options] [object...] [-- path...]\n"
        , "  git gaw check [--branch <name>]\n"
        , "  git gaw status [--diagnose]\n"
        , "  git gaw help [aux|init|deploy|undeploy|branch|commit|show|check|status|config|hooks|recovery]\n"
        ]

runBranch :: [BS.ByteString] -> IO ExitCode
runBranch arguments = case arguments of
    [operation, name] | operation `elem` ["-m", "-d", "-D"] -> do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        result <-
            if operation == "-m"
                then renameBranch (runGitPosix executable) posixFileSystem directory name
                else deleteBranch (runGitPosix executable) directory name (operation == "-D")
        case result of
            Left problem -> BS.hPut stderr (renderBranchError problem) >> pure (ExitFailure 1)
            Right report -> do
                mapM_ (\warning -> BS.hPut stderr ("Warning: " <> warning <> "\n")) (branchWarnings report)
                BS.hPut
                    stdout
                    ( if operation == "-m"
                        then "Renamed GAW branch to " <> name <> ".\n"
                        else "Deleted GAW branch " <> name <> ".\n"
                    )
                pure ExitSuccess
    _ ->
        BS.hPut
            stderr
            "git-gaw: Usage: git gaw branch -m <new-name> | -d <name> | -D <name>\n"
            >> pure (ExitFailure 1)

runDeploy :: [BS.ByteString] -> IO ExitCode
runDeploy arguments = case parseDeploymentArguments "deploy" arguments of
    Left detail -> BS.hPut stderr ("git-gaw: " <> detail <> "\n") >> pure (ExitFailure 1)
    Right (branch, requestedPath, _) -> do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        cwd <- Directory.getWorkingDirectory
        let absolutePath = fmap (absoluteRequested cwd) requestedPath
        result <- deploy (runGitPosix executable) posixFileSystem directory branch absolutePath
        case result of
            Left problem -> BS.hPut stderr (renderDeployError problem) >> pure (ExitFailure 1)
            Right report -> BS.hPut stdout (renderDeployResult report) >> pure ExitSuccess

runInit :: [BS.ByteString] -> IO ExitCode
runInit arguments = case parseDeploymentArguments "init" arguments of
    Left detail -> BS.hPut stderr ("git-gaw: " <> detail <> "\n") >> pure (ExitFailure 1)
    Right (Nothing, _, _) ->
        BS.hPut
            stderr
            "git-gaw: git gaw init requires --branch <name>\n"
            >> pure (ExitFailure 1)
    Right (Just branch, requestedPath, useDefaultConfig) -> do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        cwd <- Directory.getWorkingDirectory
        let absolutePath = fmap (absoluteRequested cwd) requestedPath
        let configMode = if useDefaultConfig then DefaultConfig else EmptyConfig
        result <- initializeWithConfig configMode (runGitPosix executable) posixFileSystem directory branch absolutePath
        case result of
            Left problem -> BS.hPut stderr (renderInitError problem) >> pure (ExitFailure 1)
            Right report -> do
                BS.hPut
                    stdout
                    ( "Initialized GAW branch "
                        <> initializedBranch report
                        <> " at "
                        <> objectIdBytes (initializedCommit report)
                        <> " ("
                        <> modeName (deployedMode (initialDeployment report))
                        <> ")\n"
                    )
                pure ExitSuccess
  where
    modeName RepositoryOnly = "repository-only"
    modeName (ExistingWorktree _) = "existing-worktree"
    modeName (CreateWorktree _) = "created-worktree"

parseDeploymentArguments ::
    BS.ByteString ->
    [BS.ByteString] ->
    Either BS.ByteString (Maybe BS.ByteString, Maybe BS.ByteString, Bool)
parseDeploymentArguments commandName = go Nothing Nothing False
  where
    go branch path useDefaultConfig [] = Right (branch, path, useDefaultConfig)
    go branch path useDefaultConfig (argument : rest)
        | commandName == "init" && argument == "--use-default-config" =
            if useDefaultConfig
                then Left "Option --use-default-config may be specified only once"
                else go branch path True rest
        | null rest && argument `elem` ["--branch", "--worktree-path"] =
            Left ("Option " <> argument <> " requires a value")
        | otherwise = case optionValue "--branch" argument rest of
            Just (value, following)
                | branch /= Nothing -> Left "Option --branch may be specified only once"
                | otherwise -> go (Just value) path useDefaultConfig following
            Nothing -> case optionValue "--worktree-path" argument rest of
                Just (value, following)
                    | path /= Nothing -> Left "Option --worktree-path may be specified only once"
                    | otherwise -> go branch (Just value) useDefaultConfig following
                Nothing -> Left ("Unsupported " <> commandName <> " argument: " <> argument)
    optionValue name argument rest
        | argument == name = case rest of
            value : following -> Just (value, following)
            [] -> Nothing
        | (name <> "=") `BS.isPrefixOf` argument =
            Just (BS.drop (BS.length name + 1) argument, rest)
        | otherwise = Nothing

makeAbsolute :: BS.ByteString -> BS.ByteString -> BS.ByteString
makeAbsolute cwd path
    | BS.isPrefixOf "/" path = path
    | otherwise = cwd <> "/" <> path

absoluteRequested :: BS.ByteString -> BS.ByteString -> BS.ByteString
absoluteRequested cwd path
    | BS.null path = BS.empty
    | otherwise = normalizePosix (makeAbsolute cwd path)

normalizePosix :: BS.ByteString -> BS.ByteString
normalizePosix bytes = "/" <> BS.intercalate "/" (foldl step [] (BS.split 47 bytes))
  where
    step parts component
        | component == "" || component == "." = parts
        | component == ".." = if null parts then [] else init parts
        | otherwise = parts ++ [component]

runUndeploy :: [BS.ByteString] -> IO ExitCode
runUndeploy arguments
    | not (null arguments) = do
        BS.hPut stderr "git-gaw: git gaw undeploy does not accept arguments\n"
        pure (ExitFailure 1)
    | otherwise = do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        result <- undeploy (runGitPosix executable) directory
        case result of
            Left (NotRepository failure) -> do
                BS.hPut stderr ("git-gaw: Not a Git repository: " <> gitStderr failure <> "\n")
                pure (ExitFailure 1)
            Right report -> do
                BS.hPut stdout (renderUndeployResult report)
                pure (if null (residuals report) then ExitSuccess else ExitFailure 1)

data MessageFragment = LiteralMessage BS.ByteString | FileMessage BS.ByteString

runCommit :: [BS.ByteString] -> IO ExitCode
runCommit arguments = case parseCommitArguments arguments of
    Left detail -> BS.hPut stderr ("git-gaw: " <> detail <> "\n") >> pure (ExitFailure 1)
    Right (fragments, revisions, allowEmpty, allowEmptyMessage) -> do
        messageResult <- makeCommitMessage fragments
        case messageResult of
            Left detail -> BS.hPut stderr detail >> pure (ExitFailure 1)
            Right message -> do
                executable <- OS.fromBytes gitExecutable
                directory <- OS.fromBytes "."
                result <-
                    createCommit
                        (runGitPosix executable)
                        posixFileSystem
                        posixClock
                        directory
                        (CommitRequest message revisions allowEmpty allowEmptyMessage)
                case result of
                    Left problem -> BS.hPut stderr (renderCommitError problem) >> pure (ExitFailure 1)
                    Right oid -> BS.hPut stdout (objectIdBytes oid <> "\n") >> pure ExitSuccess

parseCommitArguments ::
    [BS.ByteString] ->
    Either BS.ByteString ([MessageFragment], [BS.ByteString], Bool, Bool)
parseCommitArguments = go True [] [] False False
  where
    go _ fragments revisions allowEmpty allowEmptyMessage []
        | null fragments = Left "git gaw commit requires -m or -F"
        | otherwise =
            Right
                ( reverse fragments
                , reverse revisions
                , allowEmpty
                , allowEmptyMessage
                )
    go options fragments revisions allowEmpty allowEmptyMessage (argument : rest)
        | options && null rest && argument `elem` ["-m", "--message", "-F", "--file"] =
            Left ("Option " <> argument <> " requires a value")
        | options && argument == "--" =
            go False fragments revisions allowEmpty allowEmptyMessage rest
        | options && argument == "--allow-empty" =
            go options fragments revisions True allowEmptyMessage rest
        | options && argument == "--allow-empty-message" =
            go options fragments revisions allowEmpty True rest
        | options = case optionValue argument "--message" "-m" rest of
            Just (value, following) ->
                go
                    options
                    (LiteralMessage value : fragments)
                    revisions
                    allowEmpty
                    allowEmptyMessage
                    following
            Nothing -> case optionValue argument "--file" "-F" rest of
                Just (value, following) ->
                    go
                        options
                        (FileMessage value : fragments)
                        revisions
                        allowEmpty
                        allowEmptyMessage
                        following
                Nothing
                    | BS.isPrefixOf "-" argument ->
                        Left ("Unsupported commit option: " <> argument)
                Nothing ->
                    go
                        options
                        fragments
                        (argument : revisions)
                        allowEmpty
                        allowEmptyMessage
                        rest
        | otherwise =
            go
                options
                fragments
                (argument : revisions)
                allowEmpty
                allowEmptyMessage
                rest

    optionValue argument long short following
        | argument == long || argument == short = case following of
            value : rest -> Just (value, rest)
            [] -> Nothing
        | short `BS.isPrefixOf` argument && BS.length argument > BS.length short =
            Just (BS.drop (BS.length short) argument, following)
        | (long <> "=") `BS.isPrefixOf` argument =
            Just (BS.drop (BS.length long + 1) argument, following)
        | otherwise = Nothing

makeCommitMessage :: [MessageFragment] -> IO (Either BS.ByteString BS.ByteString)
makeCommitMessage = go BS.empty
  where
    go bytes [] = pure (Right bytes)
    go bytes (fragment : rest) = do
        contentResult <- case fragment of
            LiteralMessage value -> pure (Right value)
            FileMessage "-" -> Right <$> BS.hGetContents stdin
            FileMessage path -> do
                result <- try (readPosixFile path)
                case result of
                    Right value -> pure (Right value)
                    Left failure | isDoesNotExistError failure -> do
                        cwd <- Directory.getWorkingDirectory
                        let absolute = absoluteRequested cwd path
                        pure
                            ( Left
                                ( "git-gaw: The file\n         #P\""
                                    <> absolute
                                    <> "\"\n         does not exist:\n"
                                    <> "           No such file or directory\n"
                                )
                            )
                    Left failure ->
                        pure
                            ( Left
                                ( "git-gaw: "
                                    <> BS.pack (map (fromIntegral . fromEnum) (show failure))
                                    <> "\n"
                                )
                            )
        case contentResult of
            Left detail -> pure (Left detail)
            Right content -> do
                let prefix = if BS.null bytes then bytes else bytes <> "\n"
                    combined = prefix <> content
                    next = case fragment of
                        LiteralMessage _
                            | not (BS.null combined) && BS.last combined /= 10 ->
                                combined <> "\n"
                        _ -> combined
                go next rest

runCheck :: [BS.ByteString] -> IO ExitCode
runCheck arguments = do
    executable <- OS.fromBytes gitExecutable
    directory <- OS.fromBytes "."
    let git = runGitPosix executable
    result <- case arguments of
        [] -> Right <$> inspectCheck git posixFileSystem directory
        ["--branch", name] -> case parseSourceRef ("refs/heads/" <> name) of
            Left _ -> pure (Left "Invalid local branch name")
            Right source -> Right <$> inspectBranchCheck git directory source
        _ -> pure (Left "Usage: git gaw check [--branch <name>]")
    case result of
        Left detail -> BS.hPut stderr ("git-gaw: " <> detail <> "\n") >> pure (ExitFailure 1)
        Right report -> do
            BS.hPut stdout ((if null arguments then renderCheckReport else renderBranchCheckReport) report)
            pure (if checkReady report then ExitSuccess else ExitFailure 1)

runStatus :: [BS.ByteString] -> IO ExitCode
runStatus arguments
    | arguments /= [] && arguments /= ["--diagnose"] = do
        BS.hPut stderr "git-gaw: Usage: git gaw status [--diagnose]\n"
        pure (ExitFailure 1)
    | otherwise = do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        let git = runGitPosix executable
        reportResult <- inspectStatus git directory
        case reportResult of
            Left problem -> do
                BS.hPut stderr (renderStatusError problem)
                pure (ExitFailure 1)
            Right report -> do
                BS.hPut stdout (renderStatusReport report)
                if arguments == ["--diagnose"]
                    then do
                        result <-
                            runGit
                                git
                                ( GitInvocation
                                    directory
                                    [ "fsck"
                                    , "--connectivity-only"
                                    , "--no-reflogs"
                                    , "--no-dangling"
                                    , "--no-progress"
                                    ]
                                    Nothing
                                    []
                                )
                        BS.hPut stdout (gitStdout result)
                        BS.hPut stderr (gitStderr result)
                        pure $
                            if gitExitCode result /= 0
                                then ExitFailure (gitExitCode result)
                                else if statusHealthy report then ExitSuccess else ExitFailure 1
                    else pure ExitSuccess

renderStatusError :: StatusError -> BS.ByteString
renderStatusError problem = case problem of
    StatusNotRepository result ->
        "git-gaw: GAW status failed (not-repository): "
            <> gitStderr result
            <> "\n"
    StatusGitFailure _ result ->
        "git-gaw: GAW status failed (query-failed): "
            <> gitStderr result
            <> "\n"
    StatusMalformed detail ->
        "git-gaw: GAW status failed (query-failed): "
            <> detail
            <> "\n"

runHook :: [BS.ByteString] -> IO ExitCode
runHook phases = case phases of
    [phase] -> case parseHookPhase phase of
        Left problem -> reportHookError problem
        Right parsed -> do
            input <- if parsed == Preparing then BS.hGetContents stdin else pure BS.empty
            executable <- OS.fromBytes gitExecutable
            directory <- OS.fromBytes "."
            result <- evaluateTransaction (runGitPosix executable) directory parsed input
            either reportHookError (const (pure ExitSuccess)) result
    _ -> do
        BS.hPut stderr "git-gaw: git-gaw --reference-transaction requires exactly one phase\n"
        pure (ExitFailure 1)

reportHookError :: HookError -> IO ExitCode
reportHookError problem = do
    BS.hPut stderr "git-gaw: "
    BS.hPut stderr (renderHookError problem)
    BS.hPut stderr "\n"
    pure (ExitFailure 1)

renderHookError :: HookError -> BS.ByteString
renderHookError problem = case problem of
    InvalidPhase phase -> "Invalid reference-transaction phase: " <> phase
    InvalidInput detail -> "Invalid reference-transaction input: " <> detail
    ProtectedProtocolRef ref -> "Refusing to modify GAW protocol ref: " <> ref
    ProtectedRef ref -> "Refusing to modify protected GAW branch: " <> ref
    ProtectedMarker ref -> "Refusing to change .gaw/config marker on: " <> ref
    IndeterminateSource ref -> "Cannot determine GAW branch state for " <> ref <> ": state query failed"

printHelp :: BS.ByteString -> IO ExitCode
printHelp topic = case helpText topic of
    Just bytes -> BS.hPut stdout bytes >> pure ExitSuccess
    Nothing -> unknownHelp topic

unknownHelp :: BS.ByteString -> IO ExitCode
unknownHelp topic = do
    BS.hPut stderr "git-gaw: Unknown help topic: "
    BS.hPut stderr topic
    BS.hPut stderr "\n"
    pure (ExitFailure 1)

runShow :: [BS.ByteString] -> IO ExitCode
runShow arguments = case prepareShowArguments arguments of
    Left (UnsupportedOption option) -> do
        BS.hPut stderr "git-gaw: GAW show failed (:UNSUPPORTED-OPTION): unsupported option "
        BS.hPut stderr option
        BS.hPut stderr "\n"
        pure (ExitFailure 1)
    Right showArguments -> do
        executable <- OS.fromBytes gitExecutable
        directory <- OS.fromBytes "."
        result <-
            runGit
                (runGitPosix executable)
                (GitInvocation directory showArguments Nothing [("GIT_PAGER", "")])
        BS.hPut stdout (gitStdout result)
        BS.hPut stderr (gitStderr result)
        pure $ if gitExitCode result == 0 then ExitSuccess else ExitFailure (gitExitCode result)

main :: IO ()
main = Env.getArgs >>= run >>= exitWith

runAuxiliary :: [BS.ByteString] -> IO ExitCode
runAuxiliary arguments = do
    executable <- OS.fromBytes gitExecutable
    directory <- OS.fromBytes "."
    cwd <- Directory.getWorkingDirectory
    let git = runGitPosix executable
        bad detail = BS.hPut stderr ("git-gaw: " <> detail <> "\n") >> pure (ExitFailure 1)
    case arguments of
        "check" : options -> do
            sourceResult <- case options of
                [] -> do
                    current <- runGit git (GitInvocation directory ["symbolic-ref", "--quiet", "HEAD"] Nothing [])
                    pure
                        ( if gitExitCode current == 0
                            then parseSourceRef (trimLine (gitStdout current))
                            else parseSourceRef ""
                        )
                ["--branch", name] -> pure (parseSourceRef ("refs/heads/" <> name))
                _ -> pure (parseSourceRef "")
            case sourceResult of
                Left _ -> bad "aux check requires --branch <name> or a current Auxiliary worktree"
                Right source -> do
                    result <- inspectAuxiliary git directory source
                    case result of
                        Left problem -> BS.hPut stderr (renderAuxiliaryError problem) >> pure (ExitFailure 1)
                        Right report ->
                            BS.hPut stdout (renderAuxiliaryReport report)
                                >> pure (if auxiliaryValid report then ExitSuccess else ExitFailure 1)
        operation : options | operation `elem` ["init", "deploy"] ->
            case parseDeploymentArguments ("aux " <> operation) options of
                Left detail -> bad detail
                Right (branch, path, _) -> do
                    let target = fmap (absoluteRequested cwd) path
                    case (operation, branch) of
                        ("init", Nothing) -> do
                            result <- initializeAuxiliary git posixFileSystem secureUuidV4 directory target
                            case result of
                                Left problem -> BS.hPut stderr (renderAuxiliaryError problem) >> pure (ExitFailure 1)
                                Right report ->
                                    BS.hPut
                                        stdout
                                        ( "Initialized Auxiliary GAW branch "
                                            <> initializedBranch report
                                            <> " at "
                                            <> objectIdBytes (initializedCommit report)
                                            <> "\n"
                                        )
                                        >> pure ExitSuccess
                        ("deploy", Just name) -> do
                            result <- deployAuxiliary git posixFileSystem directory name target
                            case result of
                                Left problem -> BS.hPut stderr (renderDeployError problem) >> pure (ExitFailure 1)
                                Right report -> BS.hPut stdout (renderDeployResult report) >> pure ExitSuccess
                        _ -> bad "aux init accepts only --worktree-path; aux deploy requires --branch"
        _ -> bad "Usage: git gaw aux init [--worktree-path <path>] | deploy --branch <name> [--worktree-path <path>] | check [--branch <name>]"

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)
