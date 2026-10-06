{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Init
  ( InitError (..)
  , initialize
  , renderInitError
  ) where

import Control.Monad (when)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (runExceptT, throwE)
import qualified Data.ByteString as BS
import Gaw.Application.Deploy (deploy, renderDeployError)
import Gaw.Application.State (inspectCommittedObject, inspectCommittedState)
import Gaw.Protocol.Init
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data InitError = InitError BS.ByteString BS.ByteString
  deriving (Eq, Show)

renderInitError :: InitError -> BS.ByteString
renderInitError (InitError reason detail) =
  "git-gaw: GAW init failed (" <> reason <> "): " <> detail <> "\n"

initialize :: Monad m => Git m -> FileSystem m -> PosixPath
  -> BS.ByteString -> Maybe BS.ByteString -> m (Either InitError InitResult)
initialize git fs directory branch requestedPath = runExceptT $ do
  source <- validatedBranch
  probe <- command ["rev-parse", "--git-dir"] Nothing
  requireSuccess "git-failure" "Git failed while locating the repository: " probe
  names <- listRefs "refs/heads/"
  mapM_ inspectHistory names
  sourceState <- refState source
  case sourceState of
    RefMissing -> pure ()
    _ -> throwE (InitError "branch-exists"
      ("Source branch already exists: " <> quoted (refNameBytes source)))
  protocols <- listRefs "refs/gaw/"
  when (not (null protocols)) (throwE (InitError "existing-metadata"
    "Local refs/gaw metadata already exists"))
  preflightHook
  case requestedPath of
    Just path -> do
      when (BS.null path) (throwE (InitError "worktree-conflict" "Worktree path is empty"))
      exists <- lift (pathExists fs path)
      when exists (throwE (InitError "worktree-conflict"
        ("Worktree path already exists: " <> trailingSlash path)))
      listing <- command ["worktree", "list", "--porcelain", "-z"] Nothing
      requireSuccess "git-failure" "Git failed while inspecting worktrees: " listing
      let needle = "worktree " <> trimSlash path <> "\0"
      when (needle `BS.isInfixOf` gitStdout listing)
        (throwE (InitError "worktree-conflict"
          ("Worktree path is already registered: " <> trailingSlash path)))
    Nothing -> pure ()
  blob <- writeObject ["hash-object", "-w", "--stdin"] (Just initialConfig)
    "writing the initial config blob"
  gawTree <- writeObject ["mktree", "-z"]
    (Just (initialTreeEntry "100644 blob" blob "config"))
    "writing the initial .gaw tree"
  rootTree <- writeObject ["mktree", "-z"]
    (Just (initialTreeEntry "040000 tree" gawTree ".gaw"))
    "writing the initial root tree"
  commit <- writeObject
    ["-c", "user.name=Git Agent Workflow", "-c", "user.email=gaw@invalid",
     "-c", "commit.gpgSign=false", "commit-tree", objectIdBytes rootTree,
     "-m", initialMessage]
    Nothing "writing the initial root commit"
  report <- lift (inspectCommittedObject git directory commit)
  case classifyCommittedState (stateFindings report) of
    ValidCommittedState _ -> pure ()
    _ -> throwE (InitError "invalid-initial-state"
      "The generated initial commit failed validation")
  let createInput = "create " <> refNameBytes source <> "\0" <> objectIdBytes commit <>
        "\0option no-deref\0symref-create refs/gaw/HEAD\0" <> refNameBytes source <> "\0"
  created <- command (disabledHook ++ ["update-ref", "-m", "git-gaw init", "--stdin", "-z"])
    (Just createInput)
  requireSuccess "failure" "Failed to update GAW refs: " created
  deployment <- lift (deploy git fs directory (Just branch) requestedPath)
  case deployment of
    Right result -> pure (InitResult branch commit result)
    Left problem -> do
      let deleteInput = "option no-deref\0symref-delete refs/gaw/HEAD\0" <>
            refNameBytes source <> "\0delete " <> refNameBytes source <> "\0" <>
            objectIdBytes commit <> "\0"
      rollback <- command (disabledHook ++ ["update-ref", "-m", "git-gaw init rollback",
        "--stdin", "-z"]) (Just deleteInput)
      let deployDetail = dropPrefix (renderDeployError problem)
      if gitExitCode rollback == 0
        then throwE (InitError "deployment-failed" deployDetail)
        else throwE (InitError "partial-failure"
          ("Deployment failed (" <> deployDetail <>
            ") and ref compensation failed: Failed to update GAW refs: " <>
            trimLine (gitStderr rollback)))
  where
    command args input = lift (runGit git (GitInvocation directory args input []))
    requireSuccess reason prefix result
      | gitExitCode result == 0 = pure ()
      | otherwise = throwE (InitError reason (prefix <> trimLine (gitStderr result)))
    validatedBranch = do
      result <- command ["check-ref-format", "--branch", branch] Nothing
      if gitExitCode result /= 0 then throwE (InitError "invalid-branch"
        ("Invalid local branch name " <> quoted branch)) else
        case parseSourceRef ("refs/heads/" <> branch) of
          Right ref -> pure ref
          Left _ -> throwE (InitError "invalid-branch"
            ("Invalid local branch name " <> quoted branch))
    listRefs prefix = do
      result <- command ["for-each-ref", "--format=%(refname)", prefix] Nothing
      requireSuccess "git-failure" "Git failed while listing refs: " result
      pure (filter (not . BS.null) (BS.split 10 (gitStdout result)))
    refState ref = do
      result <- lift (inspectRef git directory ref)
      either (const (throwE (InitError "git-failure" "Cannot inspect Git ref"))) pure result
    inspectHistory name = do
      marker <- command ["ls-tree", "-z", "--full-tree", name, "--", ".gaw/config"] Nothing
      requireSuccess "git-failure" "Cannot inspect existing branch marker: " marker
      when (not (BS.null (gitStdout marker))) $ do
        ref <- case parseSourceRef name of
          Right value -> pure value
          Left _ -> throwE (InitError "git-failure" "Invalid local source ref")
        report <- lift (inspectCommittedState git directory ref)
        case classifyCommittedState (stateFindings report) of
          ValidCommittedState _ -> throwE (InitError "already-initialized"
            ("Existing branch " <> quoted name <> " already contains valid GAW history"))
          _ -> throwE (InitError "ambiguous-history"
            ("Existing branch " <> quoted name <> " contains an invalid GAW marker"))
    preflightHook = do
      values <- mapM configValues hookKeys
      case values of
        [[], [], []] -> pure ()
        [["reference-transaction"], ["git-gaw --reference-transaction"], ["true"]] ->
          pure ()
        _ -> throwE (InitError "hook-conflict"
          "The gaw-reference-transaction hook configuration is incomplete or divergent")
    configValues key = do
      let args = ["config", "--local"] ++
            (if key == "hook.gaw-reference-transaction.enabled"
              then ["--type=bool"] else []) ++ ["--get-all", key]
      result <- command args Nothing
      case gitExitCode result of
        0 -> pure (BS.split 10 (trimLine (gitStdout result)))
        1 -> pure []
        _ -> throwE (InitError "hook-conflict" "Cannot inspect protection hook")
    writeObject args input operation = do
      result <- command args input
      requireSuccess "git-failure" ("Git failed while " <> operation <> ": ") result
      case parseObjectId (trimLine (gitStdout result)) of
        Right oid -> pure oid
        Left _ -> throwE (InitError "git-failure"
          ("Git returned an invalid object ID while " <> operation))

hookKeys :: [BS.ByteString]
hookKeys = ["hook.gaw-reference-transaction.event",
  "hook.gaw-reference-transaction.command",
  "hook.gaw-reference-transaction.enabled"]

disabledHook :: [BS.ByteString]
disabledHook = ["-c", "hook.gaw-reference-transaction.enabled=false"]

dropPrefix :: BS.ByteString -> BS.ByteString
dropPrefix = trimLine . maybe BS.empty id . BS.stripPrefix "git-gaw: "

quoted :: BS.ByteString -> BS.ByteString
quoted value = "\"" <> value <> "\""

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

trimSlash :: BS.ByteString -> BS.ByteString
trimSlash = BS.dropWhileEnd (== 47)

trailingSlash :: BS.ByteString -> BS.ByteString
trailingSlash path | BS.null path || BS.last path == 47 = path
                   | otherwise = path <> "/"
