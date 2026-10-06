{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Ref
  ( RefName
  , RefNameError (..)
  , ObjectId
  , ObjectIdError (..)
  , RefState (..)
  , SelectorState (..)
  , refNameBytes
  , objectIdBytes
  , parseRefName
  , parseSourceRef
  , parseObjectId
  , classifySelector
  , selectorRef
  , isSourceRef
  , isProtocolRef
  ) where

import qualified Data.ByteString as BS
import Data.Word (Word8)

newtype RefName = RefName BS.ByteString deriving (Eq, Ord, Show)
newtype ObjectId = ObjectId BS.ByteString deriving (Eq, Ord, Show)

data RefNameError = InvalidRefName BS.ByteString | NotSourceRef BS.ByteString
  deriving (Eq, Show)

data ObjectIdError = InvalidObjectId BS.ByteString
  deriving (Eq, Show)

data RefState
  = RefMissing
  | RefDirect ObjectId
  | RefSymbolic RefName
  | RefInvalid BS.ByteString
  deriving (Eq, Show)

data SelectorState
  = SelectorMissing
  | SelectorDirect ObjectId
  | SelectorInvalidTarget RefName
  | SelectorInvalid BS.ByteString
  | SelectorSelected RefName
  deriving (Eq, Show)

refNameBytes :: RefName -> BS.ByteString
refNameBytes (RefName bytes) = bytes

objectIdBytes :: ObjectId -> BS.ByteString
objectIdBytes (ObjectId bytes) = bytes

-- Git's check-ref-format lexical restrictions. Repository existence and
-- object format are deliberately left to the Git adapter.
parseRefName :: BS.ByteString -> Either RefNameError RefName
parseRefName bytes
  | BS.null bytes = invalid
  | bytes == "@" = invalid
  | BS.head bytes == slash || BS.last bytes == slash = invalid
  | BS.last bytes == dot = invalid
  | ".." `BS.isInfixOf` bytes || "@{" `BS.isInfixOf` bytes = invalid
  | BS.any forbidden bytes = invalid
  | any badComponent (BS.split slash bytes) = invalid
  | otherwise = Right (RefName bytes)
  where
    invalid = Left (InvalidRefName bytes)
    badComponent part = BS.null part || BS.head part == dot || ".lock" `BS.isSuffixOf` part
    slash = 47
    dot = 46

parseSourceRef :: BS.ByteString -> Either RefNameError RefName
parseSourceRef bytes = do
  ref <- parseRefName bytes
  if isSourceRef ref then Right ref else Left (NotSourceRef bytes)

parseObjectId :: BS.ByteString -> Either ObjectIdError ObjectId
parseObjectId bytes
  | BS.length bytes `elem` [40, 64] && BS.all isHex bytes = Right (ObjectId bytes)
  | otherwise = Left (InvalidObjectId bytes)

selectorRef :: RefName
selectorRef = RefName "refs/gaw/HEAD"

isSourceRef :: RefName -> Bool
isSourceRef (RefName bytes) = strictPrefix "refs/heads/" bytes

isProtocolRef :: RefName -> Bool
isProtocolRef (RefName bytes) = strictPrefix "refs/gaw/" bytes

classifySelector :: RefState -> SelectorState
classifySelector state = case state of
  RefMissing -> SelectorMissing
  RefDirect oid -> SelectorDirect oid
  RefInvalid detail -> SelectorInvalid detail
  RefSymbolic target
    | isSourceRef target -> SelectorSelected target
    | otherwise -> SelectorInvalidTarget target

strictPrefix :: BS.ByteString -> BS.ByteString -> Bool
strictPrefix prefix value = BS.length value > BS.length prefix && prefix `BS.isPrefixOf` value

forbidden :: Word8 -> Bool
forbidden byte = byte <= 32 || byte == 127 || byte `elem` [126, 94, 58, 63, 42, 91, 92]

isHex :: Word8 -> Bool
isHex byte = (byte >= 48 && byte <= 57)
  || (byte >= 65 && byte <= 70)
  || (byte >= 97 && byte <= 102)
