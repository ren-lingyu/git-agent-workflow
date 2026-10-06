{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Branch
  ( BranchOperation (..)
  , BranchResult (..)
  , RenamePlan
  , planRename
  , oldSource
  , newSource
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Ref (RefName)

data BranchOperation = Rename | Delete deriving (Eq, Show)

data BranchResult = BranchResult
  { branchOperation :: BranchOperation
  , previousSource :: RefName
  , resultingSource :: Maybe RefName
  } deriving (Eq, Show)

data RenamePlan = RenamePlan RefName RefName deriving (Eq, Show)

planRename :: RefName -> RefName -> RefName -> Either BS.ByteString RenamePlan
planRename current selected destination
  | current /= selected = Left "The worktree branch is not refs/gaw/HEAD"
  | otherwise = Right (RenamePlan current destination)

oldSource :: RenamePlan -> RefName
oldSource (RenamePlan old _) = old

newSource :: RenamePlan -> RefName
newSource (RenamePlan _ new) = new
