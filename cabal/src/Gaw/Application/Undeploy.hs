{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Undeploy
  ( UndeployError (..)
  , undeploy
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Ref
import Gaw.Protocol.Undeploy
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data UndeployError = NotRepository GitResult
  deriving (Eq, Show)

undeploy :: Monad m => Git m -> PosixPath -> m (Either UndeployError UndeployResult)
undeploy git directory = do
  probe <- invoke ["rev-parse", "--git-dir"] Nothing
  if gitExitCode probe /= 0 then pure (Left (NotRepository probe)) else do
    selectorResult <- inspectRef git directory selectorRef
    let selector = either (const RefMissing) id selectorResult
        firstResidual = case selectorResult of
          Left _ -> ["Cannot inspect refs/gaw/HEAD: Git ref query failed"]
          Right _ -> []
    protocols <- listRefs "refs/gaw/"
    sources <- listRefs "refs/heads/"
    let candidates = case (protocols, sources) of
          (Right protocolRefs, Right sourceRefs) ->
            undeployCandidates selector protocolRefs sourceRefs
          _ -> []
        discoveryResidual = case (protocols, sources) of
          (Right _, Right _) -> []
          _ -> ["Cannot discover protocol refs: Git ref query failed"]
    (didRemoveSelector, selectorResidual) <- deleteSelector selector
    (legacyRemoved, legacyResidual) <- cleanCandidates candidates
    (didClearHook, hookResidual) <- clearHook
    pure (Right (UndeployResult didRemoveSelector legacyRemoved didClearHook
      (firstResidual ++ discoveryResidual ++ selectorResidual ++ legacyResidual ++ hookResidual)))
  where
    invoke args input = runGit git (GitInvocation directory args input [])

    listRefs prefix = do
      result <- invoke ["for-each-ref", "--format=%(refname)", prefix] Nothing
      pure $ if gitExitCode result == 0
        then Right (filter (not . BS.null) (BS.split 10 (gitStdout result)))
        else Left result

    deleteSelector RefMissing = pure (False, [])
    deleteSelector _ = do
      actual <- inspectRef git directory selectorRef
      case actual of
        Left _ -> pure (False, ["Cannot remove refs/gaw/HEAD: Git ref query failed"])
        Right RefMissing -> pure (True, [])
        Right current -> do
          let input = case current of
                RefSymbolic target -> symrefDelete "refs/gaw/HEAD" (refNameBytes target)
                RefDirect oid -> directDelete "refs/gaw/HEAD" (objectIdBytes oid)
                RefInvalid _ -> BS.empty
          if BS.null input then pure (False,
            ["Cannot remove refs/gaw/HEAD: Invalid Git ref state"])
          else do
            result <- invoke (hookDisabled ++
              ["update-ref", "-m", "git-gaw undeploy", "--stdin", "-z"])
              (Just input)
            pure $ if gitExitCode result == 0
              then (True, [])
              else (False, ["Cannot remove refs/gaw/HEAD: Failed to update GAW refs: " <>
                gitStderr result])

    cleanCandidates [] = pure ([], [])
    cleanCandidates (name:rest) = do
      (removed, problems) <- if name == "refs/gaw/HEAD"
        then pure ([], []) else cleanOne name
      (moreRemoved, moreProblems) <- cleanCandidates rest
      pure (removed ++ moreRemoved, problems ++ moreProblems)

    cleanOne name = case parseRefName name of
      Left _ -> pure ([], ["Cannot inspect " <> name <> ": Invalid Git ref name"])
      Right ref -> do
        state <- inspectRef git directory ref
        case state of
          Left _ -> pure ([], ["Cannot inspect " <> name <> ": Git ref query failed"])
          Right RefMissing -> pure ([], [])
          Right present
            | safeLegacyRegistration name present -> case present of
                RefSymbolic target -> do
                  result <- invoke (hookDisabled ++ ["update-ref", "-m",
                    "git-gaw undeploy legacy registration", "--stdin", "-z"])
                    (Just (symrefDelete name (refNameBytes target)))
                  pure $ if gitExitCode result == 0
                    then ([name], [])
                    else ([], ["Cannot remove " <> name <>
                      ": Failed to update GAW refs: " <> gitStderr result])
                _ -> pure ([], [])
            | otherwise -> pure ([], ["Preserving unsafe protocol ref " <> name])

    clearHook = do
      failures <- go hookKeys
      pure $ if null failures
        then (True, [])
        else (False, ["Cannot remove GAW hook config: Cannot remove local hook keys: " <>
          BS.intercalate ", " failures])
      where
        go [] = pure []
        go (key:rest) = do
          result <- invoke ["config", "--local", "--unset-all", key] Nothing
          later <- go rest
          pure (if gitExitCode result `elem` [0, 1, 5] then later else key : later)

    hookKeys = ["hook.gaw-reference-transaction.event",
      "hook.gaw-reference-transaction.command",
      "hook.gaw-reference-transaction.enabled"]
    hookDisabled = ["-c", "hook.gaw-reference-transaction.enabled=false"]

symrefDelete :: BS.ByteString -> BS.ByteString -> BS.ByteString
symrefDelete ref oldTarget = BS.concat
  ["option no-deref\0symref-delete ", ref, "\0", oldTarget, "\0"]

directDelete :: BS.ByteString -> BS.ByteString -> BS.ByteString
directDelete ref oldOid = BS.concat
  ["option no-deref\0delete ", ref, "\0", oldOid, "\0"]
