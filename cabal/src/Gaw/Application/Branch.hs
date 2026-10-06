{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Branch
  ( BranchError (..)
  , renameBranch
  , deleteBranch
  , renderBranchError
  ) where

import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import qualified Data.ByteString as BS
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Branch
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data BranchError = BranchError BS.ByteString BS.ByteString
  deriving (Eq, Show)

renderBranchError :: BranchError -> BS.ByteString
renderBranchError (BranchError reason detail) =
  "git-gaw: GAW branch operation failed (" <> reason <> "): " <> detail <> "\n"

renameBranch :: Monad m => Git m -> FileSystem m -> PosixPath
  -> BS.ByteString -> m (Either BranchError BranchResult)
renameBranch git fs directory newName = runExceptT $ do
  rootResult <- command directory ["rev-parse", "--show-toplevel"] Nothing
  if gitExitCode rootResult /= 0 then throwE (BranchError "failure"
    "Cannot locate the worktree root") else pure ()
  root <- lift (pathFromBytes fs (trimLine (gitStdout rootResult)))
  current <- currentHead root
  selected <- currentSelected root
  destination <- branchRef root newName
  plan <- case planRename current selected destination of
    Right value -> pure value
    Left detail -> throwE (BranchError "not-current-gaw-branch" detail)
  requireDirect root (oldSource plan)
  requireValid root (oldSource plan)
  existing <- refState root (newSource plan)
  case existing of
    RefMissing -> pure ()
    _ -> throwE (BranchError "destination-exists"
      ("Destination branch exists: " <> quoted (refNameBytes (newSource plan))))
  nativeRename root newName
  protocolResult <- lift $ runExceptT
    (renameSelector root (oldSource plan) (newSource plan))
  case protocolResult of
    Left failure -> do
      rollback <- lift $ runExceptT (nativeRename root (branchTail (oldSource plan)))
      case rollback of
        Right () -> throwE (BranchError "protocol-failure"
          ("Protocol rename failed and was compensated: " <> bareError failure))
        Left compensation -> throwE (BranchError "partial-failure"
          ("Protocol rename failed (" <> bareError failure <>
            "); compensation failed: Native rename compensation failed: " <>
            bareError compensation))
    Right () -> pure ()
  verification <- lift $ runExceptT $ do
    actualHead <- currentHead root
    if actualHead /= newSource plan then throwE (BranchError "verification-failure"
      "Worktree HEAD was not renamed") else pure ()
    actualSelected <- currentSelected root
    if actualSelected /= newSource plan then throwE (BranchError "verification-failure"
      "refs/gaw/HEAD was not renamed") else pure ()
    requireValid root (newSource plan)
  case verification of
    Right () -> pure (BranchResult Rename (oldSource plan) (Just (newSource plan)))
    Left failure -> do
      selectorRollback <- lift $ runExceptT
        (renameSelector root (newSource plan) (oldSource plan))
      nativeRollback <- lift $ runExceptT
        (nativeRename root (branchTail (oldSource plan)))
      let errors = [bareError problem | Left problem <- [selectorRollback, nativeRollback]]
      throwE (BranchError
        (if null errors then "verification-failure" else "partial-failure")
        ("Rename verification failed (" <> bareError failure <> ")" <>
          if null errors then "" else "; compensation failed: " <>
            BS.intercalate "; " errors))
  where
    command = invoke git
    branchRef = validatedBranch git
    currentHead at = do
      result <- command at ["symbolic-ref", "--quiet", "HEAD"] Nothing
      case (gitExitCode result, parseSourceRef (trimLine (gitStdout result))) of
        (0, Right ref) -> pure ref
        _ -> throwE (BranchError "failure" "The worktree HEAD is not a local branch")
    currentSelected at = selectedRef git at
    refState at ref = inspect git at ref
    requireDirect at ref = directSource git at ref
    requireValid at ref = validSource git at ref
    nativeRename at name = do
      result <- command at (disabledHook ++ ["branch", "-m", name]) Nothing
      if gitExitCode result == 0 then pure () else throwE (BranchError "native-failure"
        ("Git failed while renaming the branch: " <> trimLine (gitStderr result)))
    renameSelector at old new = do
      let input = "option no-deref\0symref-update refs/gaw/HEAD\0" <>
            refNameBytes new <> "\0ref\0" <> refNameBytes old <> "\0"
      result <- command at (disabledHook ++ ["update-ref", "-m",
        "git-gaw branch rename", "--stdin", "-z"]) (Just input)
      if gitExitCode result == 0 then pure () else throwE (BranchError "protocol-failure"
        ("Failed to update GAW refs: " <> trimLine (gitStderr result)))

deleteBranch :: Monad m => Git m -> PosixPath -> BS.ByteString -> Bool
  -> m (Either BranchError BranchResult)
deleteBranch git directory name force = runExceptT $ do
  source <- validatedBranch git directory name
  directSource git directory source
  validSource git directory source
  selector <- inspect git directory selectorRef
  case selector of
    RefMissing -> pure ()
    _ -> do
      selected <- selectedRef git directory
      validSource git directory selected
      if selected == source then throwE (BranchError "selected-branch"
        "Run git gaw undeploy or select another branch with git gaw deploy --branch before deletion")
      else pure ()
  result <- invoke git directory
    (disabledHook ++ ["branch", if force then "-D" else "-d", name]) Nothing
  if gitExitCode result == 0 then pure (BranchResult Delete source Nothing)
  else throwE (BranchError "native-failure"
    ("Git failed while deleting the branch: " <> trimLine (gitStderr result)))

invoke :: Monad m => Git m -> PosixPath -> [BS.ByteString]
  -> Maybe BS.ByteString -> ExceptT BranchError m GitResult
invoke git at args input = lift (runGit git (GitInvocation at args input []))

inspect :: Monad m => Git m -> PosixPath -> RefName -> ExceptT BranchError m RefState
inspect git at ref = do
  result <- lift (inspectRef git at ref)
  either (const (throwE (BranchError "failure" "Cannot inspect Git ref"))) pure result

validatedBranch :: Monad m => Git m -> PosixPath -> BS.ByteString
  -> ExceptT BranchError m RefName
validatedBranch git at name = do
  result <- invoke git at ["check-ref-format", "--branch", name] Nothing
  if gitExitCode result /= 0 then throwE (BranchError "invalid-name"
    ("Invalid branch name " <> quoted name)) else
    case parseSourceRef ("refs/heads/" <> name) of
      Right ref -> pure ref
      Left _ -> throwE (BranchError "invalid-name" ("Invalid branch name " <> quoted name))

directSource :: Monad m => Git m -> PosixPath -> RefName -> ExceptT BranchError m ()
directSource git at source = do
  state <- inspect git at source
  case state of
    RefDirect _ -> pure ()
    _ -> throwE (BranchError "missing-branch"
      ("Local branch does not exist: " <> quoted (refNameBytes source)))

validSource :: Monad m => Git m -> PosixPath -> RefName -> ExceptT BranchError m ()
validSource git at source = do
  report <- lift (inspectCommittedState git at source)
  case classifyCommittedState (stateFindings report) of
    ValidCommittedState _ -> pure ()
    _ -> throwE (BranchError "invalid-state"
      ("Branch is not valid GAW committed state: " <> quoted (refNameBytes source)))

selectedRef :: Monad m => Git m -> PosixPath -> ExceptT BranchError m RefName
selectedRef git at = do
  selector <- inspect git at selectorRef
  case selector of
    RefSymbolic target | isSourceRef target -> do
      state <- inspect git at target
      case state of
        RefDirect _ -> pure target
        _ -> throwE invalidSelector
    _ -> throwE invalidSelector
  where invalidSelector = BranchError "invalid-selector" "Cannot resolve GAW selector"

disabledHook :: [BS.ByteString]
disabledHook = ["-c", "hook.gaw-reference-transaction.enabled=false"]

branchTail :: RefName -> BS.ByteString
branchTail = BS.drop (BS.length "refs/heads/") . refNameBytes

bareError :: BranchError -> BS.ByteString
bareError (BranchError reason detail) =
  "GAW branch operation failed (" <> reason <> "): " <> detail

quoted :: BS.ByteString -> BS.ByteString
quoted value = "\"" <> value <> "\""

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)
