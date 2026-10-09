{-# LANGUAGE OverloadedStrings #-}

module Gaw.System.Repository
  ( RefQueryError (..)
  , SnapshotParseError (..)
  , SnapshotQueryError (..)
  , inspectRef
  , parseIndexRecords
  , parseTreeRecords
  , readIndexRecords
  , readTreeRecords
  , parseChangedPaths
  , readChangedPaths
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Ref
import Gaw.Protocol.Workspace (GitEntry (..))
import Gaw.System.Git
import System.OsPath.Posix (PosixPath)

data RefQueryError = RefQueryGitFailure [BS.ByteString] GitResult
  deriving (Eq, Show)

data SnapshotParseError
  = UnterminatedRecord
  | MalformedRecord BS.ByteString
  deriving (Eq, Show)

data SnapshotQueryError
  = SnapshotGitFailure [BS.ByteString] GitResult
  | SnapshotMalformed SnapshotParseError
  deriving (Eq, Show)

inspectRef :: Monad m => Git m -> PosixPath -> RefName -> m (Either RefQueryError RefState)
inspectRef git directory ref = do
  exists <- invoke git directory ["show-ref", "--exists", name]
  case gitExitCode exists of
    2 -> pure (Right RefMissing)
    0 -> inspectExisting
    _ -> pure (Left (RefQueryGitFailure ["show-ref", "--exists", name] exists))
  where
    name = refNameBytes ref
    inspectExisting = do
      symbolic <- invoke git directory ["symbolic-ref", "--quiet", "--no-recurse", name]
      case gitExitCode symbolic of
        0 -> pure $ Right $ case parseRefName (trimLine (gitStdout symbolic)) of
          Right target -> RefSymbolic target
          Left _ -> RefInvalid (gitStdout symbolic)
        1 -> do
          direct <- invoke git directory ["rev-parse", "--verify", "--end-of-options", name]
          pure $ case gitExitCode direct of
            0 -> Right $ case parseObjectId (trimLine (gitStdout direct)) of
              Right oid -> RefDirect oid
              Left _ -> RefInvalid (gitStdout direct)
            _ -> Left (RefQueryGitFailure ["rev-parse", "--verify", "--end-of-options", name] direct)
        _ -> pure (Left (RefQueryGitFailure ["symbolic-ref", "--quiet", "--no-recurse", name] symbolic))

invoke :: Monad m => Git m -> PosixPath -> [BS.ByteString] -> m GitResult
invoke git directory arguments = runGit git (GitInvocation directory arguments Nothing [])

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

parseIndexRecords :: BS.ByteString -> Either SnapshotParseError [GitEntry]
parseIndexRecords input = records input >>= traverse parseIndexRecord

parseTreeRecords :: BS.ByteString -> Either SnapshotParseError [GitEntry]
parseTreeRecords input = records input >>= traverse parseTreeRecord

readIndexRecords :: Monad m => Git m -> PosixPath -> m (Either SnapshotQueryError [GitEntry])
readIndexRecords git directory = do
  let arguments = ["ls-files", "--stage", "-z", "--full-name", "--", ":/"]
  result <- invoke git directory arguments
  pure (parseSnapshot arguments result parseIndexRecords)

readTreeRecords :: Monad m => Git m -> PosixPath -> ObjectId
  -> m (Either SnapshotQueryError [GitEntry])
readTreeRecords git directory tree = do
  let arguments = ["ls-tree", "-r", "-t", "-z", "--full-tree", objectIdBytes tree]
  result <- invoke git directory arguments
  pure (parseSnapshot arguments result parseTreeRecords)

parseChangedPaths :: BS.ByteString -> Either SnapshotParseError [BS.ByteString]
parseChangedPaths input = do
  paths <- records input
  if any BS.null paths then Left (MalformedRecord input) else Right paths

readChangedPaths :: Monad m => Git m -> PosixPath -> ObjectId -> ObjectId
  -> m (Either SnapshotQueryError [BS.ByteString])
readChangedPaths git directory before after = do
  let arguments = ["diff-tree", "-r", "--no-commit-id", "--name-only", "-z",
        "--no-renames", "--no-ext-diff", "--no-textconv",
        objectIdBytes before, objectIdBytes after, "--"]
  result <- invoke git directory arguments
  pure (parseSnapshot arguments result parseChangedPaths)

parseSnapshot :: [BS.ByteString] -> GitResult
  -> (BS.ByteString -> Either SnapshotParseError a)
  -> Either SnapshotQueryError a
parseSnapshot arguments result parser
  | gitExitCode result /= 0 = Left (SnapshotGitFailure arguments result)
  | otherwise = either (Left . SnapshotMalformed) Right (parser (gitStdout result))

records :: BS.ByteString -> Either SnapshotParseError [BS.ByteString]
records input
  | BS.null input = Right []
  | BS.last input /= 0 = Left UnterminatedRecord
  | otherwise = Right (init (BS.split 0 input))

parseIndexRecord :: BS.ByteString -> Either SnapshotParseError GitEntry
parseIndexRecord record = case BS.break (== 9) record of
  (header, rest) | not (BS.null rest) && not (BS.null (BS.tail rest)) ->
    case BS.split 32 header of
      [mode, oid, stage]
        | ascii mode && ascii oid && stage `elem` ["0", "1", "2", "3"] ->
            Right (GitEntry mode (if mode == "160000" then "commit" else "blob")
              oid (BS.tail rest) (fromIntegral (BS.head stage - 48)) False)
      _ -> Left (MalformedRecord record)
  _ -> Left (MalformedRecord record)

parseTreeRecord :: BS.ByteString -> Either SnapshotParseError GitEntry
parseTreeRecord record = case BS.break (== 9) record of
  (header, rest) | not (BS.null rest) && not (BS.null (BS.tail rest)) ->
    case BS.split 32 header of
      [mode, objectType, oid]
        | ascii mode && ascii objectType && ascii oid ->
            Right (GitEntry mode objectType oid (BS.tail rest) 0 False)
      _ -> Left (MalformedRecord record)
  _ -> Left (MalformedRecord record)

ascii :: BS.ByteString -> Bool
ascii bytes = not (BS.null bytes) && BS.all (< 128) bytes
