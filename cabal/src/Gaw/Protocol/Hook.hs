{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Hook
  ( HookError (..)
  , HookPhase (..)
  , RefUpdate (..)
  , TransactionValue (..)
  , CommittedClass (..)
  , SourceObservation (..)
  , MarkerObservation (..)
  , parseHookPhase
  , parseReferenceTransaction
  , protectProtocolRef
  , checkProtectedSource
  ) where

import qualified Data.ByteString as BS
import Data.Word (Word8)

data HookError
  = InvalidPhase BS.ByteString
  | InvalidInput BS.ByteString
  | ProtectedProtocolRef BS.ByteString
  | ProtectedRef BS.ByteString
  | ProtectedMarker BS.ByteString
  | IndeterminateSource BS.ByteString
  deriving (Eq, Show)

data HookPhase = Preparing | Prepared | Committed | Aborted
  deriving (Eq, Show)

data TransactionValue
  = ObjectValue BS.ByteString
  | SymbolicValue BS.ByteString
  deriving (Eq, Show)

data RefUpdate = RefUpdate
  { updateOldValue :: TransactionValue
  , updateNewValue :: TransactionValue
  , updateRef :: BS.ByteString
  } deriving (Eq, Show)

data CommittedClass = ValidCommitted | InvalidCommitted | IndeterminateCommitted
  deriving (Eq, Show)

data MarkerObservation = MarkerObservation
  { markerOldEntry :: BS.ByteString
  , markerOldClass :: CommittedClass
  , markerNewEntry :: Maybe BS.ByteString
  } deriving (Eq, Show)

data SourceObservation
  = SourceMissing
  | SourceSymbolic
  | SourceDirect BS.ByteString (Maybe MarkerObservation)
  deriving (Eq, Show)

parseHookPhase :: BS.ByteString -> Either HookError HookPhase
parseHookPhase phase = case phase of
  "preparing" -> Right Preparing
  "prepared" -> Right Prepared
  "committed" -> Right Committed
  "aborted" -> Right Aborted
  _ -> Left (InvalidPhase phase)

parseReferenceTransaction :: BS.ByteString -> Either HookError [RefUpdate]
parseReferenceTransaction input = traverse parseLine linesOfInput
  where
    pieces = BS.split 10 input
    linesOfInput = case reverse pieces of
      [] -> []
      final:rest
        | BS.null input -> []
        | BS.null final -> reverse rest
        | otherwise -> pieces

parseLine :: BS.ByteString -> Either HookError RefUpdate
parseLine line = case BS.split 32 line of
  [oldValue, newValue, ref]
    | validRef ref -> RefUpdate <$> parseValue oldValue <*> parseValue newValue <*> pure ref
  _ -> Left (InvalidInput "expected three space-separated fields")

parseValue :: BS.ByteString -> Either HookError TransactionValue
parseValue value
  | BS.null value = Left (InvalidInput "invalid transaction value")
  | BS.all hexDigit value = Right (ObjectValue value)
  | BS.length value > 4 && "ref:" `BS.isPrefixOf` value && BS.all (not . whitespace) value =
      Right (SymbolicValue (BS.drop 4 value))
  | otherwise = Left (InvalidInput "invalid transaction value")

validRef :: BS.ByteString -> Bool
validRef ref = not (BS.null ref) && BS.all (not . whitespace) ref

whitespace :: Word8 -> Bool
whitespace c = c `elem` [9, 10, 13, 32]

hexDigit :: Word8 -> Bool
hexDigit c = (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)

protectProtocolRef :: RefUpdate -> Either HookError ()
protectProtocolRef update
  | "refs/gaw/" `strictPrefixOf` updateRef update = Left (ProtectedProtocolRef (updateRef update))
  | otherwise = Right ()

checkProtectedSource :: RefUpdate -> BS.ByteString -> SourceObservation -> Either HookError ()
checkProtectedSource update sourceRef observation = case observation of
  SourceMissing -> Right ()
  SourceSymbolic -> Left (IndeterminateSource sourceRef)
  SourceDirect actualOld maybeMarker -> case maybeMarker of
    Nothing -> Right ()
    Just marker
      | markerOldClass marker == IndeterminateCommitted -> Left (IndeterminateSource sourceRef)
      | actualOld == newObject -> Right ()
      | markerOldClass marker == ValidCommitted -> Left (ProtectedRef sourceRef)
      | markerNewEntry marker /= Just (markerOldEntry marker) -> Left (ProtectedMarker sourceRef)
      | otherwise -> Right ()
  where
    newObject = case updateNewValue update of
      ObjectValue oid -> oid
      SymbolicValue _ -> BS.empty

strictPrefixOf :: BS.ByteString -> BS.ByteString -> Bool
strictPrefixOf prefix value = BS.length value > BS.length prefix && prefix `BS.isPrefixOf` value
