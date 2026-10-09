{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import CliConfig (configCliTests)
import Control.Exception (finally, try, SomeException)
import Control.Monad (forM_)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.Maybe (fromMaybe)
import Data.IORef (newIORef, modifyIORef', readIORef)
import Gaw.Application.Commit (createCommit)
import Gaw.Application.Branch (renameBranch, BranchError (..))
import Gaw.Application.Init (initialize, InitError (..))
import Gaw.Application.State
import Gaw.Application.Undeploy (undeploy)
import Gaw.Protocol.Commit
import Gaw.Protocol.State
import Gaw.Protocol.Undeploy (UndeployResult (..))
import Gaw.System.ExternalGit (gitExecutable)
import Gaw.System.Git
import Gaw.System.Repository
import Gaw.System.Config
import Gaw.System.Clock (Clock (..))
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.FileSystem (posixFileSystem)
import Gaw.Protocol.Ref
import qualified System.OsString.Posix as OS
import qualified System.Posix.Directory.ByteString as Directory
import qualified System.Posix.Env.ByteString as Env
import qualified System.Posix.Temp.ByteString as Temp
import qualified System.Directory as FileDirectory
import System.Exit (exitFailure)

main :: IO ()
main = do
  tempRoot <- fromMaybe "/tmp" <$> Env.getEnv "TMPDIR"
  temp <- Temp.mkdtemp (tempRoot <> "/gaw-git-adapter-")
  let rawDirectory = temp <> "/" <> BS.pack [255]
  (do
      Directory.createDirectory rawDirectory 0o700
      executable <- OS.fromBytes gitExecutable
      directory <- OS.fromBytes rawDirectory
      let capability = runGitPosix executable
          versionInvocation = GitInvocation directory ["--version"] Nothing []
      success <- runGit capability versionInvocation
      require (gitExitCode success == 0 && "git version " `BS.isPrefixOf` gitStdout success)
      missing <- OS.fromBytes (temp <> "/missing")
      failure <- runGit capability (versionInvocation {gitDirectory = missing})
      require (gitExitCode failure /= 0)
      rejected <- try (runGit capability (versionInvocation {gitEnvironment = [("GIT_CONFIG_GLOBAL", "unsafe")]}))
        :: IO (Either SomeException GitResult)
      require (case rejected of Left _ -> True; Right _ -> False)
      let fake = Git $ \request -> pure $ case gitArguments request of
            ["show-ref", "--exists", "refs/gaw/HEAD"] -> GitResult 0 "" ""
            ["symbolic-ref", "--quiet", "--no-recurse", "refs/gaw/HEAD"] ->
              GitResult 0 "refs/heads/agents\n" ""
            _ -> GitResult 99 "" "unexpected invocation"
      inspected <- inspectRef fake directory selectorRef
      require $ case inspected of
        Right (RefSymbolic target) -> refNameBytes target == "refs/heads/agents"
        _ -> False
      let failed = Git $ \_ -> pure (GitResult 3 "" "injected failure")
      failureResult <- inspectRef failed directory selectorRef
      require $ case failureResult of
        Left (RefQueryGitFailure _ result) -> gitExitCode result == 3
        _ -> False
      case parseObjectId (BS.replicate 40 97) of
        Left _ -> exitFailure
        Right oid -> do
          let oversized = Git $ \request -> pure $ case gitArguments request of
                ["cat-file", "-t", _] -> GitResult 0 "blob\n" ""
                ["cat-file", "-s", _] -> GitResult 0 "65537\n" ""
                _ -> GitResult 99 "" "blob body must not be read"
          configResult <- readConfigBlob oversized directory oid
          require (configResult == Left (ConfigTooLarge 65537))
      case parseSourceRef "refs/heads/agents" of
        Left _ -> exitFailure
        Right source -> do
          let commit = BS.replicate 40 97
              tree = BS.replicate 40 98
              blob = BS.replicate 40 99
              subtree = BS.replicate 40 100
              configBytes = "(:workspace ())"
              objectTree = BS.concat ["040000 tree ", subtree, "\t.gaw\0",
                                      "100644 blob ", blob, "\t.gaw/config\0"]
              scripted = Git $ \request -> pure $ case gitArguments request of
                ["rev-parse", "--verify", "--end-of-options", "refs/heads/agents^{commit}"] -> GitResult 0 (commit <> "\n") ""
                ["rev-parse", "--verify", "--end-of-options", revision]
                  | revision == commit <> "^{tree}" -> GitResult 0 (tree <> "\n") ""
                ["cat-file", "-t", oid]
                  | oid == tree -> GitResult 0 "tree\n" ""
                  | oid == blob -> GitResult 0 "blob\n" ""
                ["--literal-pathspecs", "ls-tree", "--full-tree", _, oid, "--", ".gaw/config"]
                  | oid == tree -> GitResult 0 ("100644 blob " <> blob <> "\n") ""
                ["cat-file", "-s", oid]
                  | oid == blob -> GitResult 0 (BSC.pack (show (BS.length configBytes)) <> "\n") ""
                ["cat-file", "blob", oid]
                  | oid == blob -> GitResult 0 configBytes ""
                ["ls-tree", "-r", "-t", "-z", "--full-tree", oid]
                  | oid == tree -> GitResult 0 objectTree ""
                ["rev-list", "--parents", "-n", "1", oid]
                  | oid == commit -> GitResult 0 (commit <> "\n") ""
                _ -> GitResult 99 "" "unexpected state query"
          report <- inspectCommittedState scripted directory source
          require $ case classifyCommittedState (stateFindings report) of
            ValidCommittedState _ -> True
            _ -> False
          let gawParent = BS.replicate 40 100
              projectParent = BS.replicate 40 101
              projectTree = BS.replicate 40 102
              conflicting = Git $ \request -> case gitArguments request of
                ["rev-list", "--parents", "-n", "1", oid]
                  | oid == commit -> pure (GitResult 0
                    (commit <> " " <> gawParent <> " " <> projectParent <> "\n") "")
                ["rev-parse", "--verify", "--end-of-options", revision]
                  | revision == projectParent <> "^{tree}" -> pure (GitResult 0 (projectTree <> "\n") "")
                ["ls-tree", "-r", "-t", "-z", "--full-tree", oid]
                  | oid == projectTree -> pure (GitResult 0
                    ("040000 tree " <> subtree <> "\t.gaw\0") "")
                _ -> runGit scripted request
          conflictReport <- inspectCommittedState conflicting directory source
          let conflictOk =
                case classifyCommittedState (stateFindings conflictReport) of
                  InvalidCommittedState findings -> any (\f -> findingName f == ProjectParents
                    && findingStatus f == FindingError) findings
                  _ -> False
          if conflictOk then pure () else print conflictReport >> exitFailure
          renameCalls <- newIORef []
          let renameGit = Git $ \request -> do
                modifyIORef' renameCalls (request:)
                case gitArguments request of
                  ["rev-parse", "--show-toplevel"] -> pure
                    (GitResult 0 (rawDirectory <> "\n") "")
                  ["symbolic-ref", "--quiet", "HEAD"] -> pure
                    (GitResult 0 "refs/heads/agents\n" "")
                  ["show-ref", "--exists", "refs/gaw/HEAD"] -> pure
                    (GitResult 0 "" "")
                  ["symbolic-ref", "--quiet", "--no-recurse", "refs/gaw/HEAD"] ->
                    pure (GitResult 0 "refs/heads/agents\n" "")
                  ["show-ref", "--exists", "refs/heads/agents"] -> pure
                    (GitResult 0 "" "")
                  ["symbolic-ref", "--quiet", "--no-recurse", "refs/heads/agents"] ->
                    pure (GitResult 1 "" "")
                  ["rev-parse", "--verify", "--end-of-options", "refs/heads/agents"] ->
                    pure (GitResult 0 (commit <> "\n") "")
                  ["show-ref", "--exists", "refs/heads/renamed"] -> pure
                    (GitResult 2 "" "")
                  ["check-ref-format", "--branch", "renamed"] -> pure
                    (GitResult 0 "renamed\n" "")
                  ["-c", "hook.gaw-reference-transaction.enabled=false", "branch", "-m", _] ->
                    pure (GitResult 0 "" "")
                  ["-c", "hook.gaw-reference-transaction.enabled=false", "update-ref",
                    "-m", "git-gaw branch rename", "--stdin", "-z"] ->
                    pure (GitResult 1 "" "injected selector failure")
                  _ -> runGit scripted request
          renameResult <- renameBranch renameGit
            (FileSystem (\_ -> pure False) OS.fromBytes) directory "renamed"
          require $ case renameResult of
            Left (BranchError "protocol-failure" _) -> True
            _ -> False
          renameObserved <- readIORef renameCalls
          let nativeRenames = [gitArguments invocation | invocation <- reverse renameObserved,
                "branch" `elem` gitArguments invocation]
          require (nativeRenames ==
            [["-c", "hook.gaw-reference-transaction.enabled=false", "branch", "-m", "renamed"],
             ["-c", "hook.gaw-reference-transaction.enabled=false", "branch", "-m", "agents"]])
          forM_ [False, True] $ \injectUpdateFailure -> do
            calls <- newIORef []
            let newCommit = BS.replicate 40 101
                commitGit = Git $ \request -> do
                  modifyIORef' calls (request:)
                  case gitArguments request of
                    ["rev-parse", "--show-toplevel"] -> pure (GitResult 0 (rawDirectory <> "\n") "")
                    ["rev-parse", "--show-prefix"] -> pure (GitResult 0 "\n" "")
                    ["symbolic-ref", "--quiet", "HEAD"] -> pure
                      (GitResult 0 "refs/heads/agents\n" "")
                    ["rev-parse", "--path-format=absolute", "--git-path", name] ->
                      pure (GitResult 0 (rawDirectory <> "/" <> name <> "\n") "")
                    ["ls-files", "-u", "-z", "--full-name", "--", ":/"] ->
                      pure (GitResult 0 "" "")
                    ["write-tree"] -> pure (GitResult 0 (tree <> "\n") "")
                    ["commit-tree", givenTree, "-p", parent]
                      | givenTree == tree && parent == commit ->
                          pure (GitResult 0 (newCommit <> "\n") "")
                    ["-c", "core.hooksPath=/dev/null", "-c",
                     "hook.gaw-reference-transaction.enabled=false", "update-ref",
                     "-m", "git-gaw commit", "refs/heads/agents", newOid, oldOid]
                      | newOid == newCommit && oldOid == commit ->
                          pure (if injectUpdateFailure
                            then GitResult 1 "" "injected ref race"
                            else GitResult 0 "" "")
                    _ -> runGit scripted request
                commitRequest = CommitRequest "checkpoint\n" [] True False
            committed <- createCommit commitGit (FileSystem (\_ -> pure False) OS.fromBytes)
              (Clock (pure 1700000000)) directory commitRequest
            require $ case committed of
              Right oid -> not injectUpdateFailure && objectIdBytes oid == newCommit
              Left (CommitError RefMoved _) -> injectUpdateFailure
              _ -> False
            observed <- readIORef calls
            let created = [invocation | invocation <- observed,
                  case gitArguments invocation of
                    "commit-tree" : _ -> True
                    _ -> False]
                updated = [invocation | invocation <- observed,
                  case gitArguments invocation of
                    ["-c", "core.hooksPath=/dev/null", "-c",
                     "hook.gaw-reference-transaction.enabled=false", "update-ref",
                     "-m", "git-gaw commit", _, _, _] -> True
                    _ -> False]
            case (created, updated) of
              ([createdInvocation], [_]) -> do
                let bindings = gitEnvironment createdInvocation
                require (gitInput createdInvocation == Just "checkpoint\n"
                  && lookup "GIT_AUTHOR_DATE" bindings == Just "@1700000000 +0000"
                  && lookup "GIT_COMMITTER_DATE" bindings == Just "@1700000000 +0000")
              _ -> exitFailure
          forM_
            [ (GitResult 0 ".gaw/config\0memory/current.md\0" "", MixedProtocolChanges)
            , (GitResult 3 "" "injected diff failure", GitFailure)
            , (GitResult 0 ".gaw/config\0memory/current.md" "", GitFailure)
            , (GitResult 0 ".gaw/config\0\0" "", GitFailure)
            ] $ \(diffResult, expectedReason) -> do
              calls <- newIORef []
              let candidateTree = BS.replicate 40 102
                  expectedDiff = ["diff-tree", "-r", "--no-commit-id", "--name-only", "-z",
                    "--no-renames", "--no-ext-diff", "--no-textconv", tree, candidateTree, "--"]
                  boundaryGit = Git $ \request -> do
                    modifyIORef' calls (request:)
                    case gitArguments request of
                      ["rev-parse", "--show-toplevel"] -> pure (GitResult 0 (rawDirectory <> "\n") "")
                      ["rev-parse", "--show-prefix"] -> pure (GitResult 0 "\n" "")
                      ["symbolic-ref", "--quiet", "HEAD"] -> pure (GitResult 0 "refs/heads/agents\n" "")
                      ["rev-parse", "--path-format=absolute", "--git-path", name] ->
                        pure (GitResult 0 (rawDirectory <> "/" <> name <> "\n") "")
                      ["ls-files", "-u", "-z", "--full-name", "--", ":/"] -> pure (GitResult 0 "" "")
                      ["write-tree"] -> pure (GitResult 0 (candidateTree <> "\n") "")
                      "diff-tree" : _ -> do
                        require (gitArguments request == expectedDiff)
                        pure diffResult
                      _ -> runGit scripted (request {gitArguments =
                        map (\argument -> if argument == candidateTree then tree else argument)
                          (gitArguments request)})
              result <- createCommit boundaryGit (FileSystem (\_ -> pure False) OS.fromBytes)
                (Clock (pure 1700000000)) directory (CommitRequest "boundary\n" [] False False)
              require $ case result of
                Left (CommitError reason _) -> reason == expectedReason
                _ -> False
              observed <- readIORef calls
              let startsWith name invocation = case gitArguments invocation of
                    command : _ -> command == name
                    _ -> False
              require (length (filter (startsWith "diff-tree") observed) == 1)
              require (not (any (startsWith "commit-tree") observed))
              require (not (any (elem "update-ref" . gitArguments) observed))
      undeployCalls <- newIORef []
      let undeployGit = Git $ \request -> do
            modifyIORef' undeployCalls (request:)
            pure $ case gitArguments request of
              ["rev-parse", "--git-dir"] -> GitResult 0 ".git\n" ""
              ["show-ref", "--exists", "refs/gaw/HEAD"] -> GitResult 0 "" ""
              ["symbolic-ref", "--quiet", "--no-recurse", "refs/gaw/HEAD"] ->
                GitResult 0 "refs/heads/agents\n" ""
              ["for-each-ref", "--format=%(refname)", "refs/gaw/"] ->
                GitResult 0 "refs/gaw/HEAD\n" ""
              ["for-each-ref", "--format=%(refname)", "refs/heads/"] ->
                GitResult 0 "refs/heads/agents\n" ""
              ["show-ref", "--exists", "refs/gaw/heads/agents"] ->
                GitResult 2 "" ""
              ["-c", "hook.gaw-reference-transaction.enabled=false", "update-ref",
                "-m", "git-gaw undeploy", "--stdin", "-z"] ->
                GitResult 1 "" "injected ref failure"
              ["config", "--local", "--unset-all", key]
                | key == "hook.gaw-reference-transaction.command" ->
                    GitResult 4 "" "injected config failure"
                | otherwise -> GitResult 0 "" ""
              _ -> GitResult 99 "" "unexpected undeploy invocation"
      undeployResult <- undeploy undeployGit directory
      require $ case undeployResult of
        Right report -> not (removedSelector report) && not (hookCleared report)
          && length (residuals report) == 2
        _ -> False
      attempted <- readIORef undeployCalls
      let updates = [invocation | invocation <- attempted,
            "update-ref" `elem` gitArguments invocation]
          unsets = [invocation | invocation <- attempted,
            "--unset-all" `elem` gitArguments invocation]
      case (updates, unsets) of
        ([updateInvocation], [_, _, _]) ->
          require (gitInput updateInvocation == Just
            "option no-deref\0symref-delete refs/gaw/HEAD\0refs/heads/agents\0")
        _ -> exitFailure
      let initRepoBytes = temp <> "/init-failure"
          initRepo = BSC.unpack initRepoBytes
      FileDirectory.createDirectory initRepo
      initPath <- OS.fromBytes initRepoBytes
      let realGit = runGitPosix executable
      initialized <- runGit realGit (GitInvocation initPath
        ["init", "-q", "-b", "main"] Nothing [])
      require (gitExitCode initialized == 0)
      let failingHookGit = Git $ \request ->
            if gitArguments request == ["config", "--local",
              "hook.gaw-reference-transaction.command", "git-gaw --reference-transaction"]
            then pure (GitResult 1 "" "injected hook installation failure")
            else runGit realGit request
      initFailure <- initialize failingHookGit posixFileSystem initPath "gaw" Nothing
      require $ case initFailure of
        Left (InitError "deployment-failed" _) -> True
        _ -> False
      sourceRef <- either (const exitFailure) pure (parseSourceRef "refs/heads/gaw")
      sourceAfter <- inspectRef realGit initPath sourceRef
      selectorAfter <- inspectRef realGit initPath selectorRef
      require (sourceAfter == Right RefMissing && selectorAfter == Right RefMissing)
      FileDirectory.removePathForcibly initRepo
      configCliTests (BSC.unpack temp) (BSC.unpack gitExecutable)
      putStrLn "Git adapter tests passed"
    ) `finally` (Directory.removeDirectory rawDirectory >> Directory.removeDirectory temp)

require :: Bool -> IO ()
require True = pure ()
require False = exitFailure
