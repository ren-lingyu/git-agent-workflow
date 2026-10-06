{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Show
  ( ShowError (..)
  , prepareShowArguments
  ) where

import qualified Data.ByteString as BS

data ShowError = UnsupportedOption BS.ByteString deriving (Eq, Show)

data MergeMode = MergeOff | MergeFirstParent | MergeUnsupported
  deriving (Eq, Show)

prepareShowArguments :: [BS.ByteString] -> Either ShowError [BS.ByteString]
prepareShowArguments arguments = do
  let (options, pathspec) = break (== "--") arguments
  modes <- traverse inspectOption options
  let selectedMode = foldl (\current next -> maybe current Just next) Nothing modes
  pure $ ["show"] ++ options ++ ["--first-parent"]
    ++ (if selectedMode == Just MergeOff then [] else ["--diff-merges=first-parent"])
    ++ pathspec

inspectOption :: BS.ByteString -> Either ShowError (Maybe MergeMode)
inspectOption option
  | option `elem` ["-m", "-c", "--cc", "--remerge-diff"] = Left (UnsupportedOption option)
  | otherwise = case mergeMode option of
      Just MergeUnsupported -> Left (UnsupportedOption option)
      mode -> Right mode

mergeMode :: BS.ByteString -> Maybe MergeMode
mergeMode option
  | option == "--no-diff-merges" = Just MergeOff
  | option == "--dd" = Just MergeFirstParent
  | otherwise = case BS.stripPrefix "--diff-merges=" option of
      Just value | not (BS.null value) -> case value of
        "off" -> Just MergeOff
        "none" -> Just MergeOff
        "first-parent" -> Just MergeFirstParent
        "1" -> Just MergeFirstParent
        _ | value `elem` ["on", "m", "separate", "combined", "c", "dense-combined", "cc", "remerge", "r"] -> Just MergeUnsupported
        _ -> Nothing
      _ -> Nothing
