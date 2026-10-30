{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Gaw.Protocol.Init (
    InitResult (..),
    InitConfig (..),
    initialConfig,
    defaultConfig,
    initialMessage,
    initialTreeEntry,
) where

import qualified Data.ByteString as BS
import Data.FileEmbed (embedFile)
import Gaw.Protocol.Deploy (DeployResult)
import Gaw.Protocol.Ref (ObjectId, objectIdBytes)

data InitResult = InitResult
    { initializedBranch :: BS.ByteString
    , initializedCommit :: ObjectId
    , initialDeployment :: DeployResult
    }
    deriving (Eq, Show)

initialConfig :: BS.ByteString
initialConfig = "(:version 1 :workspace ())\n"

data InitConfig = EmptyConfig | DefaultConfig
    deriving (Eq, Show)

-- Keep this resource on the CLI's current generated schema; never reserialize it.
defaultConfig :: BS.ByteString
defaultConfig = $(embedFile "resources/default-config.txt")

initialMessage :: BS.ByteString
initialMessage = "chore(init): initialize GAW history"

initialTreeEntry :: BS.ByteString -> ObjectId -> BS.ByteString -> BS.ByteString
initialTreeEntry mode oid name =
    mode <> " " <> objectIdBytes oid <> "\t" <> name <> "\0"
