{-# LANGUAGE OverloadedStrings #-}

module Gaw.Application.State
  ( inspectCommittedState
  , inspectCommittedObject
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Config (ConfigError (UnsupportedVersion, UnrecognizedVersion), effectiveWorkspace, unsupportedVersionDetail, unrecognizedVersionDetail)
import Gaw.Protocol.Workspace.Types (Workspace)
import Gaw.Protocol.Ref
import Gaw.Protocol.State
import Gaw.Protocol.Workspace
import Gaw.System.Config
import Gaw.System.Git
import Gaw.System.Repository
import System.OsPath.Posix (PosixPath)

inspectCommittedState :: Monad m => Git m -> PosixPath -> RefName -> m StateReport
inspectCommittedState git directory source = do
  commitResult <- command git directory ["rev-parse", "--verify", "--end-of-options",
    refNameBytes source <> "^{commit}"]
  case completeOid commitResult of
    Nothing -> pure (StateReport (Just source) Nothing Nothing Nothing
      (headFailure : skipped "Skipped because HEAD does not resolve to a commit"))
    Just commit -> inspectResolvedCommit git directory (Just source) commit
  where
    headFailure = finding Head FindingError Indeterminate "The current GAW branch is unborn"
    skipped detail = map (\name -> finding name FindingSkipped Determinate detail)
      [HeadConfig, HeadWorkspace, ProjectParents]

inspectCommittedObject :: Monad m => Git m -> PosixPath -> ObjectId -> m StateReport
inspectCommittedObject git directory = inspectResolvedCommit git directory Nothing

inspectResolvedCommit :: Monad m => Git m -> PosixPath -> Maybe RefName
  -> ObjectId -> m StateReport
inspectResolvedCommit git directory source commit = inspectCommit commit
  where
    inspectCommit current = do
      treeResult <- command git directory ["rev-parse", "--verify", "--end-of-options",
        objectIdBytes current <> "^{tree}"]
      case completeOid treeResult of
        Nothing -> pure (StateReport source (Just current) Nothing Nothing
          [finding Head FindingOk Determinate "HEAD resolves to a commit",
           finding HeadConfig FindingError Indeterminate "Cannot inspect HEAD config",
           finding HeadWorkspace FindingSkipped Determinate "Skipped because HEAD config is unavailable",
           finding ProjectParents FindingSkipped Determinate "Skipped because HEAD config is unavailable"])
        Just tree -> do
          configResult <- readConfigAtTree git directory tree
          case configResult of
            Left problem -> pure (StateReport source (Just current) (Just tree) Nothing
              [finding Head FindingOk Determinate "HEAD resolves to a commit",
               finding HeadConfig FindingError (configCertainty problem) (configDetail problem),
               finding HeadWorkspace FindingSkipped Determinate "Skipped because HEAD config is unavailable",
               finding ProjectParents FindingSkipped Determinate "Skipped because HEAD config is unavailable"])
            Right config -> inspectWorkspace current tree config
    inspectWorkspace current tree config = do
      treeEntries <- readTreeRecords git directory tree
      let workspaceFinding = case treeEntries of
            Left _ -> finding HeadWorkspace FindingError Indeterminate "Cannot validate the HEAD workspace"
            Right entries -> case validateWorkspace (effectiveWorkspace config) entries of
              Right () -> finding HeadWorkspace FindingOk Determinate
                "HEAD satisfies its workspace declaration"
              Left problem -> finding HeadWorkspace FindingError (workspaceCertainty problem)
                (workspaceDetail problem)
      parentFinding <- inspectParents git directory current (effectiveWorkspace config)
      pure (StateReport source (Just current) (Just tree) (Just config)
        [finding Head FindingOk Determinate "HEAD resolves to a commit",
         finding HeadConfig FindingOk Determinate "HEAD contains a valid .gaw/config",
         workspaceFinding, parentFinding])

inspectParents :: Monad m => Git m -> PosixPath -> ObjectId -> Workspace -> m StateFinding
inspectParents git directory commit workspace = do
  result <- command git directory ["rev-list", "--parents", "-n", "1", objectIdBytes commit]
  case parseParents commit result of
    Nothing -> pure (queryFailure ProjectParents "Cannot validate project parents")
    Just parents -> go (drop 1 parents)
  where
    go [] = pure (finding ProjectParents FindingOk Determinate
      "The associated project parent trees are disjoint")
    go (parent:rest) = do
      treeResult <- command git directory ["rev-parse", "--verify", "--end-of-options",
        objectIdBytes parent <> "^{tree}"]
      case completeOid treeResult of
        Nothing -> pure (queryFailure ProjectParents "Cannot validate project parents")
        Just tree -> do
          entriesResult <- readTreeRecords git directory tree
          case entriesResult of
            Left _ -> pure (queryFailure ProjectParents "Cannot validate project parents")
            Right entries -> case firstProjectPathConflict workspace entries of
              Just _ -> pure (finding ProjectParents FindingError Determinate
                "An associated project parent tracks a reserved or workspace path")
              Nothing -> go rest

parseParents :: ObjectId -> GitResult -> Maybe [ObjectId]
parseParents commit result
  | gitExitCode result /= 0 = Nothing
  | otherwise = case traverse (either (const Nothing) Just . parseObjectId)
      (BS.split 32 (trimLine (gitStdout result))) of
      Just (headOid:parents) | headOid == commit -> Just parents
      _ -> Nothing

command :: Monad m => Git m -> PosixPath -> [BS.ByteString] -> m GitResult
command git directory args = runGit git (GitInvocation directory args Nothing [])

completeOid :: GitResult -> Maybe ObjectId
completeOid result
  | gitExitCode result == 0 = either (const Nothing) Just (parseObjectId (trimLine (gitStdout result)))
  | otherwise = Nothing

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

finding :: FindingName -> FindingStatus -> Certainty -> BS.ByteString -> StateFinding
finding name status certainty detail = StateFinding name status detail certainty

queryFailure :: FindingName -> BS.ByteString -> StateFinding
queryFailure name = finding name FindingError Indeterminate

configCertainty :: ConfigReadError -> Certainty
configCertainty problem = case problem of
  InvalidConfig (UnsupportedVersion _) -> Indeterminate
  InvalidConfig (UnrecognizedVersion _) -> Indeterminate
  ConfigGitFailure _ _ -> Indeterminate
  WrongTreeObject _ -> Indeterminate
  InvalidConfigSize _ -> Indeterminate
  ConfigSizeChanged _ _ -> Indeterminate
  _ -> Determinate

configDetail :: ConfigReadError -> BS.ByteString
configDetail problem = case problem of
  MissingConfig -> "Invalid HEAD config: Invalid GAW config (:MISSING): .gaw/config is absent from the current GAW commit"
  InvalidConfigEntry _ -> "Invalid HEAD config: Invalid GAW config (:INVALID-OBJECT): .gaw/config is not a 100644 blob"
  ConfigTooLarge _ -> "Invalid HEAD config: Config exceeds 65536 octets"
  InvalidConfig (UnsupportedVersion version) -> unsupportedVersionDetail version
  InvalidConfig (UnrecognizedVersion token) -> unrecognizedVersionDetail token
  InvalidConfig _ -> "Invalid HEAD config"
  _ -> "Cannot inspect HEAD config"

workspaceCertainty :: WorkspaceError -> Certainty
workspaceCertainty problem = case problem of
  UnmergedIndex _ -> Indeterminate
  _ -> Determinate

workspaceDetail :: WorkspaceError -> BS.ByteString
workspaceDetail problem = case problem of
  UnmergedIndex _ -> "The index contains unmerged entries"
  IntentToAdd _ -> "The index contains an intent-to-add entry"
  UnsupportedEntry _ -> "The GAW tree contains an unsupported object"
  WrongDeclaredKind _ -> "A declared workspace path has the wrong Git kind"
  NoncanonicalProtocolPath _ -> "The reserved protocol path has non-canonical spelling"
  OutsideDeclaredWorkspace _ -> "The GAW tree contains a path outside the declared workspace"
