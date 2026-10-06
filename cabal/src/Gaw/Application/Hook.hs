{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Hook
  ( evaluateTransaction
  ) where

import qualified Data.ByteString as BS
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Hook
import Gaw.Protocol.Ref
import Gaw.Protocol.State (CommittedState (..), classifyCommittedState, stateFindings)
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

evaluateTransaction :: Monad m => Git m -> PosixPath -> HookPhase -> BS.ByteString
  -> m (Either HookError ())
evaluateTransaction _ _ phase _ | phase /= Preparing = pure (Right ())
evaluateTransaction git directory _ input = case parseReferenceTransaction input of
  Left problem -> pure (Left problem)
  Right updates -> go updates
  where
    go [] = pure (Right ())
    go (update:rest) = case protectProtocolRef update of
      Left problem -> pure (Left problem)
      Right () -> do
        checked <- checkUpdate update
        case checked of
          Left problem -> pure (Left problem)
          Right () -> go rest

    checkUpdate update = do
      source <- sourceForUpdate update
      case source of
        Left problem -> pure (Left problem)
        Right Nothing -> pure (Right ())
        Right (Just ref) -> do
          observation <- observeSource update ref
          pure (observation >>= checkProtectedSource update (refNameBytes ref))

    sourceForUpdate update = case parseRefName (updateRef update) of
      Left _ -> pure (Left (IndeterminateSource (updateRef update)))
      Right ref
        | "refs/heads/" `BS.isPrefixOf` updateRef update -> pure (Right (Just ref))
        | isSymbolicUpdate update -> pure (Right Nothing)
        | otherwise -> resolveSymbolic [] ref

    resolveSymbolic seen ref
      | ref `elem` seen = pure (Left (IndeterminateSource (refNameBytes ref)))
      | otherwise = do
          query <- inspectRef git directory ref
          case query of
            Left _ -> pure (Left (IndeterminateSource (refNameBytes ref)))
            Right (RefSymbolic target)
              | "refs/heads/" `BS.isPrefixOf` refNameBytes target -> pure (Right (Just target))
              | otherwise -> resolveSymbolic (ref:seen) target
            Right _ -> pure (Right Nothing)

    observeSource update ref = do
      query <- inspectRef git directory ref
      case query of
        Left _ -> pure (Left (IndeterminateSource (refNameBytes ref)))
        Right RefMissing -> pure (Right SourceMissing)
        Right (RefSymbolic _) -> pure (Right SourceSymbolic)
        Right (RefInvalid _) -> pure (Right SourceSymbolic)
        Right (RefDirect oldOid) -> do
          marker <- markerAt oldOid
          case marker of
            Left problem -> pure (Left problem)
            Right Nothing -> pure (Right (SourceDirect (objectIdBytes oldOid) Nothing))
            Right (Just oldEntry) -> do
              report <- inspectCommittedState git directory ref
              let classification = case classifyCommittedState (stateFindings report) of
                    ValidCommittedState _ -> ValidCommitted
                    InvalidCommittedState _ -> InvalidCommitted
                    IndeterminateCommittedState _ -> IndeterminateCommitted
              newEntry <- case updateNewValue update of
                ObjectValue value | not (BS.all (== 48) value) ->
                  case parseObjectId value of
                    Right oid -> markerAt oid
                    Left _ -> pure (Left (IndeterminateSource (refNameBytes ref)))
                _ -> pure (Right Nothing)
              pure $ SourceDirect (objectIdBytes oldOid) . Just .
                MarkerObservation oldEntry classification <$> newEntry

    markerAt oid = do
      let args = ["ls-tree", "-z", "--full-tree", objectIdBytes oid, "--", ".gaw/config"]
      result <- runGit git (GitInvocation directory args Nothing [])
      pure $ if gitExitCode result /= 0
        then Left (IndeterminateSource (objectIdBytes oid))
        else case gitStdout result of
          bytes | BS.null bytes -> Right Nothing
          bytes -> case BS.break (== 9) bytes of
            (entry, suffix)
              | suffix == "\t.gaw/config\0" && not (BS.null entry) -> Right (Just entry)
            _ -> Left (IndeterminateSource (objectIdBytes oid))

isSymbolicUpdate :: RefUpdate -> Bool
isSymbolicUpdate update = case (updateOldValue update, updateNewValue update) of
  (SymbolicValue _, _) -> True
  (_, SymbolicValue _) -> True
  _ -> False
