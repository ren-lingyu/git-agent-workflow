{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.AuxiliaryCheck (inspectAuxiliary, associatedWorktrees) where

import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (runExceptT, throwE)
import qualified Data.ByteString as BS
import Gaw.Application.Auxiliary (AuxiliaryError (..))
import Gaw.Application.State (inspectCommittedObjectAt)
import Gaw.Application.Status (parseWorktrees)
import Gaw.Protocol.Auxiliary
import Gaw.Protocol.Layout
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.Protocol.Status (worktreeBranch, worktreePath)
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

inspectAuxiliary :: Monad m => Git m -> PosixPath -> RefName
  -> m (Either AuxiliaryError AuxiliaryReport)
inspectAuxiliary git directory source = runExceptT $ do
  uuid <- maybe (throwE (AuxiliaryError "invalid-branch" "A canonical Auxiliary branch is required")) pure
    (auxiliaryUuid source)
  state <- refState source
  tip <- case state of
    RefDirect oid -> pure oid
    _ -> throwE (AuxiliaryError "missing-branch" "Auxiliary branch is missing, symbolic or unreadable")
  report <- lift (inspectCommittedObjectAt git directory (Auxiliary uuid) tip)
  selector <- refState selectorRef
  (formalTip, valid, retained) <- case selector of
    RefSymbolic formal | isSourceRef formal && not (auxiliaryReserved formal) -> do
      formalRef <- refState formal
      case formalRef of
        RefDirect oid -> do
          formalReport <- lift (inspectCommittedObjectAt git directory Formal oid)
          let valid = case classifyCommittedState (stateFindings formalReport) of
                ValidCommittedState _ -> True
                _ -> False
          if valid then do
            ancestry <- lift (runGit git (GitInvocation directory
              ["merge-base", "--is-ancestor", objectIdBytes tip, objectIdBytes oid] Nothing []))
            retained <- case gitExitCode ancestry of
              0 -> pure (Just True)
              1 -> pure (Just False)
              _ -> throwE (AuxiliaryError "git-failure" "Cannot inspect integration ancestry")
            pure (Just oid, True, retained)
          else pure (Just oid, False, Nothing)
        _ -> pure (Nothing, False, Nothing)
    _ -> pure (Nothing, False, Nothing)
  trees <- lift (associatedWorktrees git directory source) >>= either throwE pure
  pure (AuxiliaryReport source tip report selector formalTip valid retained trees)
  where
    refState ref = lift (inspectRef git directory ref) >>= either
      (const (throwE (AuxiliaryError "git-failure" "Cannot inspect Git ref"))) pure

associatedWorktrees :: Monad m => Git m -> PosixPath -> RefName
  -> m (Either AuxiliaryError [BS.ByteString])
associatedWorktrees git directory source = do
  listing <- runGit git (GitInvocation directory ["worktree", "list", "--porcelain", "-z"] Nothing [])
  pure $ if gitExitCode listing /= 0 then Left failure else
    case parseWorktrees (gitStdout listing) of
      Left _ -> Left failure
      Right trees -> Right [worktreePath tree | tree <- trees,
        worktreeBranch tree == Just (refNameBytes source)]
  where failure = AuxiliaryError "git-failure" "Cannot determine worktree associations"
