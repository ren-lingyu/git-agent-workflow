{-# LANGUAGE OverloadedStrings #-}

module Gaw.System.Config
  ( ConfigReadError (..)
  , readConfigAtTree
  , readConfigBlob
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Gaw.Protocol.Config (Config, ConfigError, parseConfig)
import Gaw.Protocol.Ref (ObjectId, objectIdBytes, parseObjectId)
import Gaw.System.Git
import System.OsPath.Posix (PosixPath)

data ConfigReadError
  = ConfigGitFailure [BS.ByteString] GitResult
  | WrongTreeObject BS.ByteString
  | WrongBlobObject BS.ByteString
  | MissingConfig
  | InvalidConfigEntry BS.ByteString
  | InvalidConfigSize BS.ByteString
  | ConfigTooLarge Integer
  | ConfigSizeChanged Integer Int
  | InvalidConfig ConfigError
  deriving (Eq, Show)

readConfigAtTree :: Monad m => Git m -> PosixPath -> ObjectId
  -> m (Either ConfigReadError Config)
readConfigAtTree git directory tree = do
  kind <- invoke git directory ["cat-file", "-t", objectIdBytes tree]
  if gitExitCode kind /= 0
    then pure (Left (ConfigGitFailure ["cat-file", "-t", objectIdBytes tree] kind))
    else if trimLine (gitStdout kind) /= "tree"
      then pure (Left (WrongTreeObject (gitStdout kind)))
      else do
        let arguments = ["--literal-pathspecs", "ls-tree", "--full-tree",
                         "--format=%(objectmode) %(objecttype) %(objectname)",
                         objectIdBytes tree, "--", ".gaw/config"]
        entry <- invoke git directory arguments
        if gitExitCode entry /= 0
          then pure (Left (ConfigGitFailure arguments entry))
          else case BS.split 32 (trimLine (gitStdout entry)) of
            [] -> pure (Left MissingConfig)
            [empty] | BS.null empty -> pure (Left MissingConfig)
            ["100644", "blob", oid] -> case parseObjectId oid of
              Right validOid -> readConfigBlob git directory validOid
              Left _ -> pure (Left (InvalidConfigEntry (gitStdout entry)))
            _ -> pure (Left (InvalidConfigEntry (gitStdout entry)))

readConfigBlob :: Monad m => Git m -> PosixPath -> ObjectId
  -> m (Either ConfigReadError Config)
readConfigBlob git directory oid = do
  let typeArguments = ["cat-file", "-t", objectIdBytes oid]
  kind <- invoke git directory typeArguments
  if gitExitCode kind /= 0
    then pure (Left (ConfigGitFailure typeArguments kind))
    else if trimLine (gitStdout kind) /= "blob"
      then pure (Left (WrongBlobObject (gitStdout kind)))
      else readConfigBlobBytes git directory (objectIdBytes oid)

readConfigBlobBytes :: Monad m => Git m -> PosixPath -> BS.ByteString
  -> m (Either ConfigReadError Config)
readConfigBlobBytes git directory oid = do
  let sizeArguments = ["cat-file", "-s", oid]
  sizeResult <- invoke git directory sizeArguments
  if gitExitCode sizeResult /= 0
    then pure (Left (ConfigGitFailure sizeArguments sizeResult))
    else case parseSize (trimLine (gitStdout sizeResult)) of
      Nothing -> pure (Left (InvalidConfigSize (gitStdout sizeResult)))
      Just size | size > 65536 -> pure (Left (ConfigTooLarge size))
      Just size -> do
        let blobArguments = ["cat-file", "blob", oid]
        blob <- invoke git directory blobArguments
        pure $ if gitExitCode blob /= 0
          then Left (ConfigGitFailure blobArguments blob)
          else if toInteger (BS.length (gitStdout blob)) /= size
            then Left (ConfigSizeChanged size (BS.length (gitStdout blob)))
            else either (Left . InvalidConfig) Right (parseConfig (gitStdout blob))

invoke :: Monad m => Git m -> PosixPath -> [BS.ByteString] -> m GitResult
invoke git directory arguments = runGit git (GitInvocation directory arguments Nothing [])

trimLine :: BS.ByteString -> BS.ByteString
trimLine = BS.dropWhileEnd (\byte -> byte == 10 || byte == 13)

parseSize :: BS.ByteString -> Maybe Integer
parseSize bytes = case BSC.readInteger bytes of
  Just (number, rest) | BS.null rest && number >= 0 -> Just number
  _ -> Nothing
