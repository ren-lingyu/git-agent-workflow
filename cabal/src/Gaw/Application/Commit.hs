{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Commit
  ( createCommit
  ) where

import Control.Monad (forM, when)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (runExceptT, throwE)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Commit
import Gaw.Protocol.Ref
import Gaw.Protocol.State (CommittedState (..), classifyCommittedState, stateFindings)
import Gaw.System.Clock (Clock (..))
import Gaw.Protocol.Config (effectiveWorkspace)
import Gaw.System.Config (readConfigAtTree)
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (readTreeRecords)
import System.OsPath.Posix (PosixPath)

createCommit :: Monad m => Git m -> FileSystem m -> Clock m -> PosixPath
  -> CommitRequest -> m (Either CommitError ObjectId)
createCommit git fs clock directory request = runExceptT $ do
  when (BS.null (requestMessage request) && not (requestAllowEmptyMessage request)) $
    throwE (CommitError EmptyMessage "The commit message is empty")
  _ <- gitOutput ["rev-parse", "--show-toplevel"] NotWorktreeRoot
    "The directory is not a Git worktree"
  prefix <- gitOutput ["rev-parse", "--show-prefix"] NotWorktreeRoot
    "The directory is not a Git worktree"
  when (not (BS.null (trimLine prefix))) $
    throwE (CommitError NotWorktreeRoot "git gaw commit must run at the worktree root")
  sourceBytes <- gitOutput ["symbolic-ref", "--quiet", "HEAD"] DetachedHead
    "The worktree HEAD is detached or unborn"
  source <- case parseSourceRef (trimLine sourceBytes) of
    Right value -> pure value
    Left _ -> throwE (CommitError DetachedHead "The worktree HEAD is not a local branch")
  states <- operationStates
  case states of
    name : _ -> throwE (CommitError OperationInProgress
      ("Git operation state is present: " <> name))
    [] -> pure ()
  unmerged <- gitOutput ["ls-files", "-u", "-z", "--full-name", "--", ":/"]
    CommitUnmergedIndex "Cannot inspect the Git index"
  when (not (BS.null unmerged)) $
    throwE (CommitError CommitUnmergedIndex "The index contains unmerged entries")
  firstParent <- resolveOid (refNameBytes source <> "^{commit}") DetachedHead
    "The current GAW branch is unborn"
  stagedTreeBytes <- gitOutput ["write-tree"] GitFailure "Cannot write the staged GAW tree"
  stagedTree <- checkedOid stagedTreeBytes
  entries <- treeEntries stagedTree
  oldReport <- lift (inspectCommittedState git directory source)
  case classifyCommittedState (stateFindings oldReport) of
    ValidCommittedState _ -> pure ()
    _ -> throwE (CommitError CommitInvalidCommittedState
      "The current branch is not valid GAW committed state")
  stagedConfigResult <- lift (readConfigAtTree git directory stagedTree)
  config <- either (const (throwE (CommitError InvalidWorkspace
    "Invalid staged config"))) pure stagedConfigResult
  projects <- forM (requestProjectRevisions request) $ \revision -> do
    oid <- resolveOid (revision <> "^{commit}") InvalidProjectCommit
      ("Cannot resolve project commit \"" <> revision <> "\"")
    tree <- resolveOid (objectIdBytes oid <> "^{tree}") GitFailure
      "Cannot resolve a project commit tree"
    projectEntries <- treeEntries tree
    pure (oid, projectEntries)
  firstTree <- resolveOid (objectIdBytes firstParent <> "^{tree}") GitFailure
    "Cannot resolve the first parent tree"
  plan <- either throwE pure (planCommit request source firstParent firstTree stagedTree
    (effectiveWorkspace config) entries projects)
  timestamp <- lift (unixTimestamp clock)
  let date = "@" <> BSC.pack (show timestamp) <> " +0000"
      identity = [("GIT_AUTHOR_NAME", "Git Agent Workflow"),
                  ("GIT_AUTHOR_EMAIL", "gaw@invalid"),
                  ("GIT_COMMITTER_NAME", "Git Agent Workflow"),
                  ("GIT_COMMITTER_EMAIL", "gaw@invalid"),
                  ("GIT_AUTHOR_DATE", date), ("GIT_COMMITTER_DATE", date)]
      commitArgs = ["commit-tree", objectIdBytes (plannedTree plan)] ++
        concatMap (\oid -> ["-p", objectIdBytes oid]) (plannedParents plan)
  created <- lift (runGit git (GitInvocation directory commitArgs
    (Just (plannedMessage plan)) identity))
  when (gitExitCode created /= 0) $
    throwE (CommitError GitFailure "Cannot create the GAW commit object")
  newOid <- checkedOid (gitStdout created)
  let updateArgs = ["-c", "core.hooksPath=/dev/null",
        "-c", "hook.gaw-reference-transaction.enabled=false",
        "update-ref", "-m", "git-gaw commit", refNameBytes source,
        objectIdBytes newOid, objectIdBytes firstParent]
  updated <- lift (runGit git (GitInvocation directory updateArgs Nothing []))
  when (gitExitCode updated /= 0) $
    throwE (CommitError RefMoved "The GAW branch changed before it could be updated")
  pure newOid
  where
    gitOutput args reason detail = do
      result <- lift (runGit git (GitInvocation directory args Nothing []))
      if gitExitCode result == 0 then pure (gitStdout result)
        else throwE (CommitError reason detail)

    checkedOid output = case parseObjectId (trimLine output) of
      Right oid -> pure oid
      Left _ -> throwE (CommitError GitFailure "Git returned a malformed object ID")

    resolveOid revision reason detail = do
      output <- gitOutput ["rev-parse", "--verify", "--end-of-options", revision]
        reason detail
      checkedOid output

    treeEntries tree = do
      result <- lift (readTreeRecords git directory tree)
      either (const (throwE (CommitError GitFailure "Cannot read a Git tree")))
        pure result

    operationStates = go ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD",
      "REBASE_HEAD", "rebase-merge", "rebase-apply", "sequencer", "BISECT_LOG"]
      where
        go [] = pure []
        go (name:rest) = do
          output <- gitOutput ["rev-parse", "--path-format=absolute", "--git-path", name]
            GitFailure "Cannot locate Git operation state"
          exists <- lift (pathExists fs (trimLine output))
          suffix <- go rest
          pure (if exists then name : suffix else suffix)

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)
