{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Check
  ( inspectCheck
  ) where

import qualified Data.ByteString as BS
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Check
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.Protocol.Workspace
import Gaw.System.Config (readConfigBlob)
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (inspectRef, readIndexRecords)
import System.OsPath.Posix (PosixPath)

inspectCheck :: Monad m => Git m -> FileSystem m -> PosixPath -> m CheckReport
inspectCheck git fs directory = do
  rootResult <- command ["rev-parse", "--show-toplevel"]
  if gitExitCode rootResult /= 0
    then pure (CheckReport (finding "worktree" CheckError
      "The directory is not a Git worktree" : map skipped noWorktree))
    else do
      prefixResult <- command ["rev-parse", "--show-prefix"]
      let root = trailingSlash (trimLine (gitStdout rootResult))
          rootFinding = finding "worktree"
            (if BS.null (trimLine (gitStdout prefixResult)) then CheckOk else CheckWarning)
            ("Worktree root: " <> root <>
              if BS.null (trimLine (gitStdout prefixResult)) then "" else "; git gaw commit must run there")
      branchResult <- currentBranch
      selectorFinding <- inspectSelector
      stateFindings' <- case branchResult of
        Right source -> map fromState . stateFindings <$>
          inspectCommittedState git directory source
        Left _ -> pure (map (\name -> finding name CheckSkipped
          "Skipped because no local branch is available")
          ["head", "head-config", "head-workspace", "project-parents"])
      indexFinding <- inspectIndex
      operationFinding <- inspectOperationState
      hookFinding <- inspectHook
      let branchFinding = case branchResult of
            Right source -> finding "branch" CheckOk (refNameBytes source)
            Left detail -> finding "branch" CheckError detail
      pure (CheckReport ([rootFinding, branchFinding, selectorFinding] ++
        stateFindings' ++ [indexFinding, operationFinding, hookFinding]))
  where
    noWorktree = ["branch", "selector", "head", "head-config", "head-workspace",
                  "project-parents", "index", "operation-state", "protection-hook"]
    skipped name = finding name CheckSkipped "Skipped because no Git worktree is available"
    command args = runGit git (GitInvocation directory args Nothing [])

    currentBranch = do
      result <- command ["symbolic-ref", "--quiet", "HEAD"]
      pure $ if gitExitCode result /= 0
        then Left "The worktree HEAD is detached or unborn"
        else case parseSourceRef (trimLine (gitStdout result)) of
          Right source -> Right source
          Left _ -> Left "The worktree HEAD is not a local branch"

    inspectSelector = do
      state <- inspectRef git directory selectorRef
      case state of
        Left _ -> pure (finding "selector" CheckError "Invalid GAW selector: Git ref query failed")
        Right RefMissing -> pure (finding "selector" CheckWarning
          "GAW selector is absent; repository is not deployed")
        Right (RefSymbolic source) | isSourceRef source -> do
          sourceState <- inspectRef git directory source
          case sourceState of
            Right (RefDirect _) -> do
              report <- inspectCommittedState git directory source
              pure $ case classifyCommittedState (stateFindings report) of
                ValidCommittedState _ -> finding "selector" CheckOk
                  ("GAW selector chooses " <> refNameBytes source)
                _ -> invalidSelector
            _ -> pure invalidSelector
        Right _ -> pure invalidSelector
      where invalidSelector = finding "selector" CheckError
              "GAW selector points to a non-valid GAW branch"

    inspectIndex = do
      query <- readIndexRecords git directory
      case query of
        Left _ -> pure (finding "index" CheckError "Cannot read the Git index")
        Right rawEntries -> do
          let entries = synthesizeIndexDirectories rawEntries
          case validateSnapshot entries of
            Left problem -> pure (indexError (workspaceDetail problem))
            Right () -> case filter ((== ".gaw/config") . entryPath) entries of
              [] -> pure (indexError "The staged candidate has no .gaw/config")
              entry : _
                | entryStage entry /= 0 || entryMode entry /= "100644"
                    || entryType entry /= "blob" || BS.null (entryObjectId entry) ->
                      pure (indexError "The staged .gaw/config is not a 100644 blob")
                | otherwise -> case parseObjectId (entryObjectId entry) of
                    Left _ -> pure (indexError "The staged .gaw/config is not a 100644 blob")
                    Right oid -> do
                      config <- readConfigBlob git directory oid
                      pure $ case config of
                        Left _ -> indexError "Invalid staged config"
                        Right parsed -> case validateWorkspace parsed entries of
                          Left problem -> indexError (workspaceDetail problem)
                          Right () -> finding "index" CheckOk
                            "The staged candidate satisfies its workspace declaration"
      where indexError = finding "index" CheckError

    inspectOperationState = do
      states <- go operationNames
      pure $ if null states
        then finding "operation-state" CheckOk "No conflicting Git operation is in progress"
        else finding "operation-state" CheckError
          ("Git operation state is present: " <> BS.intercalate ", " states)
      where
        operationNames = ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "REBASE_HEAD",
          "rebase-merge", "rebase-apply", "sequencer", "BISECT_LOG"]
        go [] = pure []
        go (name:rest) = do
          result <- command ["rev-parse", "--path-format=absolute", "--git-path", name]
          exists <- if gitExitCode result == 0
            then pathExists fs (trimLine (gitStdout result)) else pure False
          suffix <- go rest
          pure (if exists then name : suffix else suffix)

    inspectHook = do
      event <- configValues "hook.gaw-reference-transaction.event" False
      hookCommand <- configValues "hook.gaw-reference-transaction.command" False
      enabled <- configValues "hook.gaw-reference-transaction.enabled" True
      pure $ case (event, hookCommand, enabled) of
        (Right [], Right [], Right []) -> finding "protection-hook" CheckWarning
          "The GAW protection hook is not configured"
        (Right ["reference-transaction"], Right ["git-gaw --reference-transaction"],
          Right ["true"]) -> finding "protection-hook" CheckOk
            "The GAW protection hook is configured"
        (Right _, Right _, Right _) -> finding "protection-hook" CheckWarning
          "The gaw-reference-transaction hook configuration is incomplete or divergent"
        _ -> finding "protection-hook" CheckWarning
          "Cannot inspect the optional protection hook: Git config query failed"

    configValues key boolean = do
      let args = ["config", "--local"] ++
            (if boolean then ["--type=bool"] else []) ++ ["--get-all", key]
      result <- command args
      pure $ case gitExitCode result of
        0 -> Right (BS.split 10 (trimLine (gitStdout result)))
        1 -> Right []
        _ -> Left ()

finding :: BS.ByteString -> CheckStatus -> BS.ByteString -> CheckFinding
finding = CheckFinding

fromState :: StateFinding -> CheckFinding
fromState state = finding (stateName (findingName state)) status (findingDetail state)
  where status = case findingStatus state of
          FindingOk -> CheckOk
          FindingError -> CheckError
          FindingSkipped -> CheckSkipped

stateName :: FindingName -> BS.ByteString
stateName name = case name of
  Head -> "head"
  HeadConfig -> "head-config"
  HeadWorkspace -> "head-workspace"
  ProjectParents -> "project-parents"

workspaceDetail :: WorkspaceError -> BS.ByteString
workspaceDetail problem = case problem of
  UnmergedIndex _ -> "The index contains unmerged entries"
  IntentToAdd _ -> "The index contains an intent-to-add entry"
  UnsupportedEntry _ -> "The GAW tree contains an unsupported object"
  WrongDeclaredKind _ -> "A declared workspace path has the wrong Git kind"
  NoncanonicalProtocolPath _ -> "The reserved protocol path has non-canonical spelling"
  OutsideDeclaredWorkspace _ -> "The GAW tree contains a path outside the declared workspace"

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

trailingSlash :: BS.ByteString -> BS.ByteString
trailingSlash path | BS.null path || BS.last path == 47 = path
                   | otherwise = path <> "/"
