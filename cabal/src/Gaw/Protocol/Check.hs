{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Check
  ( CheckStatus (..)
  , CheckFinding (..)
  , CheckReport (..)
  , checkReady
  , renderBranchCheckReport
  , renderCheckReport
  ) where

import qualified Data.ByteString as BS

data CheckStatus = CheckOk | CheckWarning | CheckError | CheckSkipped
  deriving (Eq, Show)

data CheckFinding = CheckFinding
  { checkName :: BS.ByteString
  , checkStatus :: CheckStatus
  , checkDetail :: BS.ByteString
  } deriving (Eq, Show)

newtype CheckReport = CheckReport { checkFindings :: [CheckFinding] }
  deriving (Eq, Show)

checkReady :: CheckReport -> Bool
checkReady = all ((/= CheckError) . checkStatus) . checkFindings

renderCheckReport :: CheckReport -> BS.ByteString
renderCheckReport report = BS.concat (map renderFinding (checkFindings report)) <>
  if checkReady report then "\nGAW worktree is ready.\n"
                       else "\nGAW worktree is not ready.\n"

renderFinding :: CheckFinding -> BS.ByteString
renderFinding finding = "[" <> statusName (checkStatus finding) <> "] " <>
  checkName finding <> ": " <> checkDetail finding <> "\n"

statusName :: CheckStatus -> BS.ByteString
statusName status = case status of
  CheckOk -> "ok"
  CheckWarning -> "warning"
  CheckError -> "error"
  CheckSkipped -> "skipped"

renderBranchCheckReport :: CheckReport -> BS.ByteString
renderBranchCheckReport report = BS.concat (map renderFinding (checkFindings report)) <>
  if checkReady report then "\nGAW committed state is valid; worktree readiness was not checked.\n"
  else "\nGAW committed state is invalid or indeterminate.\n"
