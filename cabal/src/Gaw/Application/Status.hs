{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.Status
  ( StatusError (..)
  , inspectStatus
  , parseWorktrees
  ) where

import qualified Data.ByteString as BS
import Data.List (sort)
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Config (configWarnings, renderConfigWarning)
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.Protocol.Status
import Gaw.System.Git
import Gaw.System.Repository (inspectRef)
import System.OsPath.Posix (PosixPath)

data StatusError
  = StatusNotRepository GitResult
  | StatusGitFailure [BS.ByteString] GitResult
  | StatusMalformed BS.ByteString
  deriving (Eq, Show)

inspectStatus :: Monad m => Git m -> PosixPath -> m (Either StatusError StatusReport)
inspectStatus git directory = do
  repository <- invoke ["rev-parse", "--path-format=absolute", "--git-common-dir"]
  if gitExitCode repository /= 0
    then pure (Left (StatusNotRepository repository))
    else do
      sourceNames <- listRefs "refs/heads/"
      protocolNames <- listRefs "refs/gaw/"
      case (sourceNames, protocolNames) of
        (Right sources, Right protocols) -> do
          branches <- traverse inspectBranch (sort sources)
          selector <- inspectProtocol "refs/gaw/HEAD"
          protocolRefs <- traverse inspectProtocol (sort protocols)
          worktrees <- readWorktrees
          hook <- readHook
          pure $ do
            branchValues <- sequence branches
            selectorValue <- selector
            refValues <- sequence protocolRefs
            trees <- worktrees
            hookValue <- hook
            let selected = classifySelected branchValues selectorValue
                refs = map (\ref -> if protocolName ref == "refs/gaw/HEAD"
                  then selected else if protocolStatus ref == ProtocolUnreadable
                    then ref else ref { protocolDetail = Just "Unexpected GAW protocol ref" })
                  refValues
            Right (StatusReport (trailingSlash (trimLine (gitStdout repository)))
              branchValues refs selected trees hookValue)
        (Left problem, _) -> pure (Left problem)
        (_, Left problem) -> pure (Left problem)
  where
    invoke args = runGit git (GitInvocation directory args Nothing [])

    listRefs prefix = do
      let args = ["for-each-ref", "--format=%(refname)", prefix]
      result <- invoke args
      pure $ if gitExitCode result /= 0
        then Left (StatusGitFailure args result)
        else Right (filter (not . BS.null) (BS.split 10 (gitStdout result)))

    inspectBranch name = case parseSourceRef name of
      Left _ -> pure (Left (StatusMalformed "Invalid source ref name"))
      Right ref -> do
        state <- inspectRef git directory ref
        case state of
          Left _ -> pure (Left (StatusMalformed "Cannot inspect a local branch"))
          Right RefMissing -> pure (Right (StatusBranch name Nothing InvalidBranch []
            (Just "Source ref is missing or symbolic")))
          Right (RefSymbolic _) -> pure (Right (StatusBranch name Nothing InvalidBranch []
            (Just "Source ref is missing or symbolic")))
          Right (RefInvalid _) -> pure (Right (StatusBranch name Nothing InvalidBranch []
            (Just "Source ref is missing or symbolic")))
          Right (RefDirect oid) -> do
            marked <- markerAt name
            case marked of
              Left problem -> pure (Left problem)
              Right False -> pure (Right (StatusBranch name (Just (objectIdBytes oid))
                OrdinaryBranch [] Nothing))
              Right True -> do
                report <- inspectCommittedState git directory ref
                let classification = classifyCommittedState (stateFindings report)
                    firstError = case filter ((== FindingError) . findingStatus)
                      (stateFindings report) of
                      first : _ -> Just (findingDetail first)
                      [] -> Nothing
                pure (Right (StatusBranch name (Just (objectIdBytes oid))
                  (case classification of
                    ValidCommittedState _ -> ValidBranch
                    InvalidCommittedState _ -> InvalidBranch
                    IndeterminateCommittedState _ -> IndeterminateBranch)
                  (maybe [] (map renderConfigWarning . configWarnings) (stateConfig report))
                  firstError))

    markerAt name = do
      let args = ["ls-tree", "-z", "--full-tree", name, "--", ".gaw/config"]
      result <- invoke args
      pure $ if gitExitCode result /= 0
        then Left (StatusGitFailure args result)
        else Right (not (BS.null (gitStdout result)))

    inspectProtocol name = case parseRefName name of
      Left _ -> pure (Left (StatusMalformed "Invalid protocol ref name"))
      Right ref -> do
        inspected <- inspectRef git directory ref
        pure $ case inspected of
          Left _ -> Right (StatusProtocolRef name Nothing False ProtocolUnreadable
            (Just "Cannot inspect protocol ref"))
          Right RefMissing -> Right (StatusProtocolRef name Nothing False ProtocolMissing Nothing)
          Right (RefSymbolic target) -> Right (StatusProtocolRef name
            (Just (refNameBytes target)) True ProtocolUnknown Nothing)
          Right (RefDirect oid) -> Right (StatusProtocolRef name
            (Just (objectIdBytes oid)) False ProtocolUnknown Nothing)
          Right (RefInvalid _) -> Right (StatusProtocolRef name Nothing False ProtocolUnreadable
            (Just "Cannot inspect protocol ref"))

    readWorktrees = do
      let args = ["worktree", "list", "--porcelain", "-z"]
      result <- invoke args
      pure $ if gitExitCode result /= 0
        then Left (StatusGitFailure args result)
        else parseWorktrees (gitStdout result)

    readHook = do
      event <- configValues "hook.gaw-reference-transaction.event" False
      hookCommand <- configValues "hook.gaw-reference-transaction.command" False
      enabled <- configValues "hook.gaw-reference-transaction.enabled" True
      pure $ case (event, hookCommand, enabled) of
        (Right [], Right [], Right []) -> Right HookAbsent
        (Right ["reference-transaction"], Right ["git-gaw --reference-transaction"],
          Right ["true"]) -> Right HookCanonical
        (Right _, Right _, Right _) -> Right HookConflict
        _ -> Left (StatusMalformed "Cannot inspect protection hook")

    configValues key boolean = do
      let args = ["config", "--local"] ++
            (if boolean then ["--type=bool"] else []) ++ ["--get-all", key]
      result <- invoke args
      pure $ case gitExitCode result of
        0 -> Right (BS.split 10 (trimLine (gitStdout result)))
        1 -> Right []
        _ -> Left (StatusGitFailure args result)

classifySelected :: [StatusBranch] -> StatusProtocolRef -> StatusProtocolRef
classifySelected branches selector = case protocolStatus selector of
  ProtocolMissing -> selector
  ProtocolUnreadable -> selector
  _ | not (protocolSymbolic selector) -> selector { protocolStatus = ProtocolInvalid,
        protocolDetail = Just "Selector must be symbolic" }
  _ -> case protocolValue selector of
    Just target | "refs/heads/" `BS.isPrefixOf` target ->
      case filter ((== target) . statusBranchRef) branches of
        [branch] | statusBranchClass branch == ValidBranch ->
          selector { protocolStatus = ProtocolValid }
        _ -> selector { protocolStatus = ProtocolInvalid,
          protocolDetail = Just "Selector does not reach a valid GAW branch" }
    Just _ -> selector { protocolStatus = ProtocolInvalid,
      protocolDetail = Just "Selector must point directly to a local branch" }
    Nothing -> selector { protocolStatus = ProtocolInvalid,
      protocolDetail = Just "Selector must be symbolic" }

parseWorktrees :: BS.ByteString -> Either StatusError [StatusWorktree]
parseWorktrees input
  | BS.null input = Right []
  | BS.last input /= 0 = Left (StatusMalformed "Unterminated worktree output")
  | otherwise = Right (go (BS.split 0 input) Nothing [])
  where
    go [] current records = reverse (maybe records (: records) current)
    go (field:rest) current records
      | BS.null field = go rest Nothing (maybe records (: records) current)
      | "worktree " `BS.isPrefixOf` field =
          let saved = maybe records (: records) current
          in go rest (Just (StatusWorktree (BS.drop 9 field) Nothing False False False)) saved
      | otherwise = go rest (fmap (update field) current) records
    update field tree
      | "branch " `BS.isPrefixOf` field = tree { worktreeBranch = Just (BS.drop 7 field) }
      | field == "detached" = tree { worktreeDetached = True }
      | field == "bare" = tree { worktreeBare = True }
      | "prunable" `BS.isPrefixOf` field = tree { worktreePrunable = True }
      | otherwise = tree

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

trailingSlash :: BS.ByteString -> BS.ByteString
trailingSlash path | BS.null path || BS.last path == 47 = path
                   | otherwise = path <> "/"
