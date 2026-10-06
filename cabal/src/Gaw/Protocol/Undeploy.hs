{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Undeploy
  ( UndeployResult (..)
  , undeployCandidates
  , legacySource
  , safeLegacyRegistration
  , renderUndeployResult
  ) where

import qualified Data.ByteString as BS
import Data.List (nub, sort)
import Gaw.Protocol.Ref (RefState (..), refNameBytes)

data UndeployResult = UndeployResult
  { removedSelector :: Bool
  , removedLegacyRefs :: [BS.ByteString]
  , hookCleared :: Bool
  , residuals :: [BS.ByteString]
  } deriving (Eq, Show)

undeployCandidates :: RefState -> [BS.ByteString] -> [BS.ByteString]
  -> [BS.ByteString]
undeployCandidates selector protocolRefs sources = sort (nub
  (protocolRefs ++ selected ++ map legacy sources))
  where
    selected = case selector of
      RefSymbolic target | "refs/gaw/" `BS.isPrefixOf` refNameBytes target ->
        [refNameBytes target]
      _ -> []
    legacy source = "refs/gaw/heads/" <> BS.drop (BS.length "refs/heads/") source

legacySource :: BS.ByteString -> Maybe BS.ByteString
legacySource name
  | "refs/gaw/heads/" `BS.isPrefixOf` name &&
      BS.length name > BS.length "refs/gaw/heads/" =
      Just ("refs/heads/" <> BS.drop (BS.length "refs/gaw/heads/") name)
  | otherwise = Nothing

safeLegacyRegistration :: BS.ByteString -> RefState -> Bool
safeLegacyRegistration name state = case (legacySource name, state) of
  (Just expected, RefSymbolic actual) -> expected == refNameBytes actual
  _ -> False

renderUndeployResult :: UndeployResult -> BS.ByteString
renderUndeployResult result = BS.concat
  (["GAW selector: ", if removedSelector result then "removed\n" else "unchanged\n",
    "GAW hook config: ", if hookCleared result then "cleared\n" else "not fully removed\n"]
   ++ map ("Removed legacy ref: " <>) (map (<> "\n") (removedLegacyRefs result))
   ++ map ("Residual: " <>) (map (<> "\n") (residuals result)))
