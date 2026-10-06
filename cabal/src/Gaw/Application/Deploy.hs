{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Deploy
  ( DeployError (..)
  , deploy
  , renderDeployError
  ) where

import Control.Monad (foldM)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (runExceptT, throwE)
import qualified Data.ByteString as BS
import Data.List (nub)
import Gaw.Application.Check (inspectCheck)
import Gaw.Application.State (inspectCommittedState)
import Gaw.Application.Status (parseWorktrees)
import Gaw.Protocol.Check (checkReady)
import Gaw.Protocol.Deploy
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data DeployError = DeployError BS.ByteString BS.ByteString
  deriving (Eq, Show)

renderDeployError :: DeployError -> BS.ByteString
renderDeployError (DeployError reason detail) =
  "git-gaw: GAW deploy failed (" <> reason <> "): " <> detail <> "\n"

deploy :: Monad m => Git m -> FileSystem m -> PosixPath
  -> Maybe BS.ByteString -> Maybe BS.ByteString
  -> m (Either DeployError DeployResult)
deploy git fs directory requestedBranch requestedPath = runExceptT $ do
  probe <- command ["rev-parse", "--git-dir"] Nothing
  requireSuccess "git-failure" "Git failed while locating the repository: " probe
  existingHook <- inspectHook
  case existingHook of
    HookConflict -> throwE (DeployError "hook-conflict"
      "The gaw-reference-transaction hook configuration is incomplete or divergent")
    _ -> pure ()
  selector <- refState selectorRef
  sourceNames <- listRefs "refs/heads/"
  protocolNames <- listRefs "refs/gaw/"
  let legacyNames = ["refs/gaw/heads/" <>
        BS.drop (BS.length "refs/heads/") source | source <- sourceNames]
      selectorLegacy = case selector of
        RefSymbolic target | "refs/gaw/heads/" `BS.isPrefixOf` refNameBytes target ->
          [refNameBytes target]
        _ -> []
  mapM_ checkProtocol (nub (protocolNames ++ selectorLegacy ++ legacyNames))
  (source, warnings) <- case requestedBranch of
    Just branch -> do
      validateBranch branch
      sourceRef <- parseSource ("refs/heads/" <> branch)
      checkOldSelection selector
      requireValid sourceRef
      pure (sourceRef, [])
    Nothing -> case selector of
      RefMissing -> discover sourceNames
      _ -> do
        selected <- validSelected selector
        requireValid selected
        pure (selected, [])
  treeRecords <- command ["worktree", "list", "--porcelain", "-z"] Nothing
  requireSuccess "git-failure" "Git failed while listing worktrees: " treeRecords
  worktrees <- case parseWorktrees (gitStdout treeRecords) of
    Right records -> pure records
    Left _ -> throwE (DeployError "git-failure" "Cannot parse Git worktree list")
  exists <- case requestedPath of
    Just path -> lift (pathExists fs path)
    Nothing -> pure False
  mode <- case planWorktree (refNameBytes source) requestedPath exists worktrees of
    Right value -> pure value
    Left problem -> throwE (worktreeError problem)
  let oldTarget = case selector of
        RefSymbolic target -> Just target
        _ -> Nothing
      selectionChanged = oldTarget /= Just source
      failed failure created = do
        rollbackFailures <- compensate selectionChanged oldTarget source mode created
        if null rollbackFailures then throwE failure else throwE (DeployError "partial-failure"
          (errorDetail failure <> "; compensation failed: " <>
            BS.intercalate "; " rollbackFailures))
  if selectionChanged then selectSource oldTarget source else pure ()
  creation <- lift $ runExceptT $ case mode of
    CreateWorktree path -> createWorktree source path >> pure True
    _ -> pure False
  case creation of
    Left failure -> failed failure False
    Right created -> do
      result <- lift $ runExceptT $ do
        case mode of
          RepositoryOnly -> pure ()
          ExistingWorktree path -> validateWorktree path
          CreateWorktree path -> validateWorktree path
        ensureHook existingHook
      case result of
        Right () -> pure (DeployResult
          (BS.drop (BS.length "refs/heads/") (refNameBytes source)) mode warnings)
        Left failure -> failed failure created
  where
    command args input = lift (runGit git (GitInvocation directory args input []))
    requireSuccess reason prefix result
      | gitExitCode result == 0 = pure ()
      | otherwise = throwE (DeployError reason (prefix <> trimLine (gitStderr result)))

    refState ref = do
      result <- lift (inspectRef git directory ref)
      either (const (throwE (DeployError "git-failure" "Cannot inspect Git ref"))) pure result

    listRefs prefix = do
      result <- command ["for-each-ref", "--format=%(refname)", prefix] Nothing
      requireSuccess "git-failure" "Failed to list Git refs: " result
      pure (filter (not . BS.null) (BS.split 10 (gitStdout result)))

    parseSource bytes = case parseSourceRef bytes of
      Right ref -> pure ref
      Left _ -> throwE (DeployError "invalid-branch"
        ("Invalid local branch name " <> quoted (BS.drop (BS.length "refs/heads/") bytes)))

    checkProtocol name
      | name == "refs/gaw/HEAD" = pure ()
      | otherwise = case parseRefName name of
          Left _ -> throwE (DeployError "corrupt-metadata" "Invalid GAW protocol ref")
          Right ref -> do
            state <- refState ref
            case state of
              RefMissing -> pure ()
              _ -> throwE (DeployError "corrupt-metadata"
                ("Unexpected or legacy GAW protocol ref " <> quoted name <>
                "; run git gaw undeploy"))

    validateBranch branch = do
      if BS.null branch then throwE (DeployError "invalid-branch" "Branch name is empty")
      else pure ()
      result <- command ["check-ref-format", "--branch", branch] Nothing
      if gitExitCode result == 0 then pure ()
      else throwE (DeployError "invalid-branch"
        ("Invalid local branch name " <> quoted branch))

    checkOldSelection state = case state of
      RefMissing -> pure ()
      _ -> validSelected state >>= requireValid

    validSelected state = case state of
      RefSymbolic target | isSourceRef target -> do
        sourceState <- refState target
        case sourceState of
          RefDirect _ -> pure target
          _ -> throwE corruptSelector
      _ -> throwE corruptSelector
      where corruptSelector = DeployError "corrupt-metadata"
              "Invalid refs/gaw/HEAD state: Cannot resolve GAW selector"

    requireValid ref = do
      report <- lift (inspectCommittedState git directory ref)
      case classifyCommittedState (stateFindings report) of
        ValidCommittedState _ -> pure ()
        _ -> throwE (DeployError "invalid-committed-state"
          ("Branch " <> quoted (refNameBytes ref) <>
          " is not valid GAW history: " <> firstStateError report))

    discover names = do
      observations <- mapM inspectCandidate names
      let valid = [ref | (ref, True, True, _) <- observations]
          warnings = ["Ignoring GAW-like branch " <> refNameBytes ref <> ": " <> detail
            | (ref, True, False, detail) <- observations]
      case valid of
        [] -> throwE (DeployError "no-candidate" "No valid local GAW branch was found")
        [one] -> pure (one, warnings)
        _ -> throwE (DeployError "ambiguous-branch"
          "Multiple valid local GAW branches were found; use --branch")

    inspectCandidate name = do
      ref <- parseSource name
      marker <- command ["ls-tree", "-z", "--full-tree", name, "--", ".gaw/config"] Nothing
      requireSuccess "git-failure" "Cannot inspect branch marker: " marker
      if BS.null (gitStdout marker) then pure (ref, False, False, "") else do
        report <- lift (inspectCommittedState git directory ref)
        let valid = case classifyCommittedState (stateFindings report) of
              ValidCommittedState _ -> True
              _ -> False
        pure (ref, True, valid, firstStateError report)

    inspectHook = do
      values <- mapM configValues hookKeys
      pure $ case values of
        [[], [], []] -> HookAbsent
        [["reference-transaction"], ["git-gaw --reference-transaction"], ["true"]] ->
          HookCanonical
        _ -> HookConflict

    configValues key = do
      let args = ["config", "--local"] ++
            (if key == "hook.gaw-reference-transaction.enabled"
              then ["--type=bool"] else []) ++ ["--get-all", key]
      result <- command args Nothing
      case gitExitCode result of
        0 -> pure (BS.split 10 (trimLine (gitStdout result)))
        1 -> pure []
        _ -> throwE (DeployError "hook-conflict" "Cannot inspect protection hook")

    selectSource old new = do
      let dataBytes = case old of
            Nothing -> "option no-deref\0symref-create refs/gaw/HEAD\0" <>
              refNameBytes new <> "\0"
            Just previous -> "option no-deref\0symref-update refs/gaw/HEAD\0" <>
              refNameBytes new <> "\0ref\0" <> refNameBytes previous <> "\0"
      result <- command (disabledHook ++ ["update-ref", "-m", "git-gaw select",
        "--stdin", "-z"]) (Just dataBytes)
      requireSuccess "failure" "Failed to update GAW refs: " result

    createWorktree source path = do
      let branch = BS.drop (BS.length "refs/heads/") (refNameBytes source)
      result <- command (disabledHook ++ ["worktree", "add", "--quiet", path, branch]) Nothing
      requireSuccess "worktree-create-failed" ("Cannot create worktree " <> path <> ": ") result

    validateWorktree path = do
      parsed <- lift (pathFromBytes fs path)
      report <- lift (inspectCheck git fs parsed)
      if checkReady report then pure () else throwE
        (DeployError "invalid-worktree" "The deployed worktree failed git gaw check")

    ensureHook HookCanonical = pure ()
    ensureHook HookConflict = throwE (DeployError "hook-conflict" "Conflicting hook config")
    ensureHook HookAbsent = do
      written <- foldM set [] installKeys
      if length written == length installKeys then pure () else pure ()
      where
        set written (key, value) = do
          result <- command ["config", "--local", key, value] Nothing
          if gitExitCode result == 0 then pure (key : written) else do
            undone <- mapM unset written
            throwE (DeployError "failure"
              (if and undone then "Cannot set local Git hook config"
               else "Hook installation failed and rollback was incomplete"))
        unset key = do
          result <- command ["config", "--local", "--unset-all", key] Nothing
          pure (gitExitCode result `elem` [0, 1, 5])

    compensate changed old source mode created = do
      worktreeErrors <- if created then case mode of
        CreateWorktree path -> do
          result <- command (disabledHook ++ ["worktree", "remove", path]) Nothing
          pure (if gitExitCode result == 0 then [] else ["Cannot remove worktree " <> path])
        _ -> pure []
        else pure []
      selectorErrors <- if changed then do
        let dataBytes = case old of
              Nothing -> "option no-deref\0symref-delete refs/gaw/HEAD\0" <>
                refNameBytes source <> "\0"
              Just previous -> "option no-deref\0symref-update refs/gaw/HEAD\0" <>
                refNameBytes previous <> "\0ref\0" <> refNameBytes source <> "\0"
        result <- command (disabledHook ++ ["update-ref", "-m", "git-gaw deploy rollback",
          "--stdin", "-z"]) (Just dataBytes)
        pure (if gitExitCode result == 0 then [] else ["Failed to restore GAW selector"])
        else pure []
      pure (worktreeErrors ++ selectorErrors)

data HookConfiguration = HookAbsent | HookCanonical | HookConflict

hookKeys :: [BS.ByteString]
hookKeys = ["hook.gaw-reference-transaction.event",
  "hook.gaw-reference-transaction.command",
  "hook.gaw-reference-transaction.enabled"]

installKeys :: [(BS.ByteString, BS.ByteString)]
installKeys = [("hook.gaw-reference-transaction.command", "git-gaw --reference-transaction"),
  ("hook.gaw-reference-transaction.event", "reference-transaction"),
  ("hook.gaw-reference-transaction.enabled", "true")]

disabledHook :: [BS.ByteString]
disabledHook = ["-c", "hook.gaw-reference-transaction.enabled=false"]

firstStateError :: StateReport -> BS.ByteString
firstStateError report = case filter ((== FindingError) . findingStatus)
  (stateFindings report) of
  first : _ -> findingDetail first
  [] -> "The committed state is invalid"

worktreeError :: WorktreePlanError -> DeployError
worktreeError problem = DeployError "worktree-conflict" (case problem of
  PathOccupied path -> "Worktree path already exists: " <> path
  PathAttachedElsewhere path -> "Worktree path " <> path <>
    " is attached to different or invalid state"
  BranchAlreadyAttached source path -> "Branch " <> source <>
    " is already attached at " <> path
  MultipleAttachments source -> "Branch " <> source <>
    " is attached to multiple worktrees")

errorDetail :: DeployError -> BS.ByteString
errorDetail (DeployError reason detail) =
  "GAW deploy failed (" <> reason <> "): " <> detail

quoted :: BS.ByteString -> BS.ByteString
quoted value = "\"" <> value <> "\""

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)
