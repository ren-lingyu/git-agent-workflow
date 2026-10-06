{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Deploy
  ( DeployMode (..)
  , DeployResult (..)
  , WorktreePlanError (..)
  , planWorktree
  , renderDeployResult
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Status (StatusWorktree (..))

data DeployMode
  = RepositoryOnly
  | ExistingWorktree BS.ByteString
  | CreateWorktree BS.ByteString
  deriving (Eq, Show)

data DeployResult = DeployResult
  { deployedBranch :: BS.ByteString
  , deployedMode :: DeployMode
  , deployWarnings :: [BS.ByteString]
  } deriving (Eq, Show)

data WorktreePlanError
  = PathOccupied BS.ByteString
  | PathAttachedElsewhere BS.ByteString
  | BranchAlreadyAttached BS.ByteString BS.ByteString
  | MultipleAttachments BS.ByteString
  deriving (Eq, Show)

planWorktree :: BS.ByteString -> Maybe BS.ByteString -> Bool
  -> [StatusWorktree] -> Either WorktreePlanError DeployMode
planWorktree source requested pathExists records = case requested of
  Just path -> case filter ((== pathKey path) . pathKey . worktreePath) records of
    atPath : _
      | attachedToSource atPath -> Right (ExistingWorktree path)
      | otherwise -> Left (PathAttachedElsewhere path)
    [] -> case attached of
      first : _ -> Left (BranchAlreadyAttached source (worktreePath first))
      [] | pathExists -> Left (PathOccupied path)
         | otherwise -> Right (CreateWorktree path)
  Nothing -> case attached of
    [] -> Right RepositoryOnly
    [only] -> Right (ExistingWorktree (worktreePath only))
    _ -> Left (MultipleAttachments source)
  where
    attached = filter attachedToSource records
    attachedToSource record = worktreeBranch record == Just source
      && not (worktreeDetached record) && not (worktreePrunable record)
    pathKey = BS.dropWhileEnd (== 47)

renderDeployResult :: DeployResult -> BS.ByteString
renderDeployResult result =
  "Deployed GAW branch " <> deployedBranch result <> " (" <>
  modeName (deployedMode result) <> ")" <>
  maybe "" (" at " <>) (modePath (deployedMode result)) <> "\n" <>
  BS.concat ["warning: " <> warning <> "\n" | warning <- deployWarnings result]
  where
    modeName RepositoryOnly = "repository-only"
    modeName (ExistingWorktree _) = "existing-worktree"
    modeName (CreateWorktree _) = "created-worktree"
    modePath RepositoryOnly = Nothing
    modePath (ExistingWorktree path) = Just (trailingSlash path)
    modePath (CreateWorktree path) = Just (trailingSlash path)
    trailingSlash path | BS.null path || BS.last path == 47 = path
                       | otherwise = path <> "/"
