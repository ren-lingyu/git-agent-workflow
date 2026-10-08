{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Init
  ( InitResult (..)
  , initialConfig
  , initialMessage
  , initialTreeEntry
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Deploy (DeployResult)
import Gaw.Protocol.Ref (ObjectId, objectIdBytes)

data InitResult = InitResult
  { initializedBranch :: BS.ByteString
  , initializedCommit :: ObjectId
  , initialDeployment :: DeployResult
  } deriving (Eq, Show)

initialConfig :: BS.ByteString
initialConfig = "(:version 1 :workspace ())\n"

initialMessage :: BS.ByteString
initialMessage = "Initialize GAW"

initialTreeEntry :: BS.ByteString -> ObjectId -> BS.ByteString -> BS.ByteString
initialTreeEntry mode oid name =
  mode <> " " <> objectIdBytes oid <> "\t" <> name <> "\0"
