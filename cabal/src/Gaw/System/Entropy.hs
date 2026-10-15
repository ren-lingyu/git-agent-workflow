{-# LANGUAGE OverloadedStrings #-}

module Gaw.System.Entropy (secureUuidV4, uuidV4) where

import Control.Exception (IOException, try)
import Data.Bits ((.&.), (.|.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Numeric (showHex)
import System.IO (withBinaryFile, IOMode (ReadMode))

-- POSIX secure random device; errors and short reads fail closed.
secureUuidV4 :: IO (Either BS.ByteString BS.ByteString)
secureUuidV4 = do
  result <- try (withBinaryFile "/dev/urandom" ReadMode (\h -> BS.hGet h 16))
    :: IO (Either IOException BS.ByteString)
  pure $ case result of
    Left _ -> Left "Cannot read the secure random source"
    Right bytes -> maybe (Left "Short read from the secure random source") Right (uuidV4 bytes)

uuidV4 :: BS.ByteString -> Maybe BS.ByteString
uuidV4 bytes
  | BS.length bytes /= 16 = Nothing
  | otherwise = Just (BSC.pack (concat
      [ (if i `elem` [4,6,8,10] then "-" else "") ++ hex value
      | (i,value) <- zip [0 :: Int ..] (BS.unpack normalized)]))
  where
    normalized = BS.pack [if i == 6 then (c .&. 15) .|. 64
      else if i == 8 then (c .&. 63) .|. 128 else c
      | (i,c) <- zip [0 :: Int ..] (BS.unpack bytes)]
    hex c = let value = showHex c "" in if length value == 1 then '0':value else value
