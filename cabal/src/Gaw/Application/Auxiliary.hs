{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Auxiliary
  ( AuxiliaryError (..), renderAuxiliaryError, initializeAuxiliary
  ) where

import Control.Monad (when)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (runExceptT, throwE)
import qualified Data.ByteString as BS
import Gaw.Application.Deploy (deployAuxiliary, renderDeployError)
import Gaw.Application.Init (createInitialRoot, renderInitError)
import Gaw.Application.Status (inspectStatus, parseWorktrees)
import Gaw.Protocol.Config (effectiveWorkspace)
import Gaw.Protocol.Workspace (GitEntry (..), firstProjectPathConflict)
import Gaw.System.Config (readConfigAtTree)
import Gaw.Protocol.Deploy
import Gaw.Protocol.Init (InitResult (..))
import Gaw.Protocol.Layout
import Gaw.Protocol.Ref
import Gaw.Protocol.Status
import Gaw.System.FileSystem (FileSystem (..))
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data AuxiliaryError = AuxiliaryError BS.ByteString BS.ByteString deriving (Eq, Show)

renderAuxiliaryError :: AuxiliaryError -> BS.ByteString
renderAuxiliaryError (AuxiliaryError reason detail) =
  "git-gaw: Auxiliary operation failed (" <> reason <> "): " <> detail <> "\n"

initializeAuxiliary :: Monad m => Git m -> FileSystem m
  -> m (Either BS.ByteString BS.ByteString) -> PosixPath -> Maybe BS.ByteString
  -> m (Either AuxiliaryError InitResult)
initializeAuxiliary git fs entropy directory requestedPath = runExceptT $ do
  status <- lift (inspectStatus git directory) >>= either
    (const (throwE (AuxiliaryError "git-failure" "Cannot inspect deployment"))) pure
  when (statusHook status /= HookCanonical) (throwE (AuxiliaryError "hook-required"
    "Auxiliary init requires the existing canonical protection hook"))
  let selector = statusSelector status
  when (protocolStatus selector /= ProtocolValid) (throwE (AuxiliaryError "invalid-selector"
    "Auxiliary init requires a valid formal GAW selector"))
  formal <- maybe (throwE invalidSelector) parseSource (protocolValue selector)
  when (auxiliaryReserved formal) (throwE invalidSelector)
  tip <- case [oid | branch <- statusBranches status,
      statusBranchRef branch == refNameBytes formal, Just oid <- [statusBranchOid branch]] of
    [oid] -> either (const (throwE invalidSelector)) pure (parseObjectId oid)
    _ -> throwE invalidSelector
  blobResult <- command ["rev-parse", "--verify", "--end-of-options",
    objectIdBytes tip <> ":.gaw/config"] Nothing
  blob <- resultOid blobResult
  treeResult <- command ["rev-parse", "--verify", "--end-of-options", objectIdBytes tip <> "^{tree}"] Nothing
  tree <- resultOid treeResult
  parsed <- lift (readConfigAtTree git directory tree)
  config <- either (const (throwE invalidSelector)) pure parsed
  (source, commit) <- createFresh formal tip blob (effectiveWorkspace config) (16 :: Int)
  deployment <- lift (deployAuxiliary git fs directory
    (BS.drop (BS.length "refs/heads/") (refNameBytes source)) requestedPath)
  case deployment of
    Right report -> pure (InitResult
      (BS.drop (BS.length "refs/heads/") (refNameBytes source)) commit report)
    Left problem -> do
      -- A failed deploy may leave a worktree. Preserve its branch in that case.
      worktrees <- command ["worktree", "list", "--porcelain", "-z"] Nothing
      let attached = case parseWorktrees (gitStdout worktrees) of
            Right records -> any ((== Just (refNameBytes source)) . worktreeBranch) records
            Left _ -> True
      if gitExitCode worktrees /= 0 || attached then throwE
        (AuxiliaryError "partial-failure" (renderDeployError problem <>
          "Branch retained because worktree cleanup could not be confirmed: " <> refNameBytes source))
      else do
        rollback <- command (disabled ++ ["update-ref", "--stdin", "-z"])
          (Just ("option no-deref\0delete " <> refNameBytes source <> "\0" <>
            objectIdBytes commit <> "\0"))
        throwE (AuxiliaryError (if gitExitCode rollback == 0 then "deployment-failed" else "partial-failure")
          (renderDeployError problem <> if gitExitCode rollback == 0 then ""
            else "Ref rollback failed; branch may remain: " <> refNameBytes source))
  where
    command args input = lift (runGit git (GitInvocation directory args input []))
    invalidSelector = AuxiliaryError "invalid-selector" "Cannot resolve a valid formal GAW selector"
    parseSource bytes = either (const (throwE invalidSelector)) pure (parseSourceRef bytes)
    resultOid result
      | gitExitCode result /= 0 = throwE (AuxiliaryError "git-failure" (gitStderr result))
      | otherwise = either (const (throwE (AuxiliaryError "git-failure" "Invalid object ID"))) pure
          (parseObjectId (trimLine (gitStdout result)))
    createFresh _ _ _ _ 0 = throwE (AuxiliaryError "uuid-collision" "Repeated UUID collisions")
    createFresh formal tip blob workspace remaining = do
      uuid <- lift entropy >>= either (throwE . AuxiliaryError "random-failure") pure
      source <- parseSource ("refs/heads/_gaw_aux_" <> uuid)
      when (auxiliaryUuid source /= Just uuid) (throwE (AuxiliaryError "random-failure" "Invalid UUIDv4"))
      let pathCollision = firstProjectPathConflict workspace
            [GitEntry "100644" "blob" "" uuid 0 False] /= Nothing
      state <- lift (inspectRef git directory source)
      case state of
        Left _ -> throwE (AuxiliaryError "git-failure" "Cannot inspect fresh branch")
        Right RefMissing | not pathCollision -> do
          listing <- command ["worktree", "list", "--porcelain", "-z"] Nothing
          records <- if gitExitCode listing == 0 then either
            (const (throwE (AuxiliaryError "git-failure" "Cannot parse worktrees"))) pure
            (parseWorktrees (gitStdout listing))
            else throwE (AuxiliaryError "git-failure" "Cannot list worktrees")
          exists <- maybe (pure False) (lift . pathExists fs) requestedPath
          either (const (throwE (AuxiliaryError "worktree-conflict" "Requested worktree path is unavailable")))
            (const (pure ())) (planWorktree (refNameBytes source) requestedPath exists records)
          generated <- lift (createInitialRoot git directory (Auxiliary uuid) blob)
          commit <- either (throwE . AuxiliaryError "root-failure" . renderInitError) pure generated
          let input = "option no-deref\0symref-verify refs/gaw/HEAD\0" <> refNameBytes formal <>
                "\0verify " <> refNameBytes formal <> "\0" <> objectIdBytes tip <>
                "\0create " <> refNameBytes source <> "\0" <> objectIdBytes commit <> "\0"
          created <- command (disabled ++ ["update-ref", "--stdin", "-z"]) (Just input)
          if gitExitCode created == 0 then pure (source, commit) else do
            raced <- lift (inspectRef git directory source)
            case raced of
              Right (RefDirect _) -> createFresh formal tip blob workspace (remaining - 1)
              _ -> throwE (AuxiliaryError "ref-changed" (gitStderr created))
        Right _ -> createFresh formal tip blob workspace (remaining - 1)

disabled :: [BS.ByteString]
disabled = ["-c", "hook.gaw-reference-transaction.enabled=false"]

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)
