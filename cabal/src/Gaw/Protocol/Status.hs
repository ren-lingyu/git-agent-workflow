{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Status
  ( BranchClass (..)
  , StatusBranch (..)
  , ProtocolStatus (..)
  , StatusProtocolRef (..)
  , HookStatus (..)
  , StatusWorktree (..)
  , StatusReport (..)
  , statusHealthy
  , renderStatusReport
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC

data BranchClass = OrdinaryBranch | ValidBranch | InvalidBranch | IndeterminateBranch
  deriving (Eq, Show)

data StatusBranch = StatusBranch
  { statusBranchRef :: BS.ByteString
  , statusBranchOid :: Maybe BS.ByteString
  , statusBranchClass :: BranchClass
  , statusBranchWarnings :: [BS.ByteString]
  , statusBranchDetail :: Maybe BS.ByteString
  } deriving (Eq, Show)

data ProtocolStatus = ProtocolMissing | ProtocolValid | ProtocolInvalid
  | ProtocolUnknown | ProtocolUnreadable
  deriving (Eq, Show)

data StatusProtocolRef = StatusProtocolRef
  { protocolName :: BS.ByteString
  , protocolValue :: Maybe BS.ByteString
  , protocolSymbolic :: Bool
  , protocolStatus :: ProtocolStatus
  , protocolDetail :: Maybe BS.ByteString
  } deriving (Eq, Show)

data HookStatus = HookAbsent | HookCanonical | HookConflict
  deriving (Eq, Show)

data StatusWorktree = StatusWorktree
  { worktreePath :: BS.ByteString
  , worktreeBranch :: Maybe BS.ByteString
  , worktreeDetached :: Bool
  , worktreeBare :: Bool
  , worktreePrunable :: Bool
  } deriving (Eq, Show)

data StatusReport = StatusReport
  { statusRepository :: BS.ByteString
  , statusBranches :: [StatusBranch]
  , statusProtocolRefs :: [StatusProtocolRef]
  , statusSelector :: StatusProtocolRef
  , statusWorktrees :: [StatusWorktree]
  , statusHook :: HookStatus
  } deriving (Eq, Show)

statusHealthy :: StatusReport -> Bool
statusHealthy report =
  all ((`elem` [OrdinaryBranch, ValidBranch]) . statusBranchClass) (statusBranches report)
  && all (not . badRef . protocolStatus) (statusProtocolRefs report)
  && protocolStatus (statusSelector report) `elem` [ProtocolMissing, ProtocolValid]
  && statusHook report /= HookConflict
  where badRef value = value `elem` [ProtocolInvalid, ProtocolUnknown, ProtocolUnreadable]

renderStatusReport :: StatusReport -> BS.ByteString
renderStatusReport report = BS.concat
  [ "GAW repository: ", statusRepository report, "\n"
  , "Selector: ", renderRef (statusSelector report), "\n"
  , "Protection hook: ", hookName (statusHook report), " (",
      hookDetail (statusHook report), ")\n"
  , "\nGAW branches (", count gawBranches, "):\n"
  , BS.concat (map renderGawBranch gawBranches)
  , "\nOrdinary branches (", count ordinaryBranches, "):\n"
  , BS.concat ["  " <> statusBranchRef branch <> "\n" | branch <- ordinaryBranches]
  , "\nGAW protocol refs (", count otherRefs, "):\n"
  , BS.concat ["  " <> protocolName ref <> " " <> renderRef ref <> "\n" | ref <- otherRefs]
  , "\nWorktrees (", count (statusWorktrees report), "):\n"
  , BS.concat (map renderWorktree (statusWorktrees report))
  ]
  where
    gawBranches = filter ((/= OrdinaryBranch) . statusBranchClass) (statusBranches report)
    ordinaryBranches = filter ((== OrdinaryBranch) . statusBranchClass) (statusBranches report)
    otherRefs = filter ((/= "refs/gaw/HEAD") . protocolName) (statusProtocolRefs report)
    renderGawBranch branch = "  " <> statusBranchRef branch <> " " <>
      maybe "" (<> " ") (statusBranchOid branch) <> branchName (statusBranchClass branch) <>
      maybe "" ("; " <>) (statusBranchDetail branch) <> "\n" <>
      BS.concat ["    warning: " <> warning <> "\n" | warning <- statusBranchWarnings branch] <>
      BS.concat ["    at " <> worktreePath tree <> "\n"
        | tree <- statusWorktrees report, worktreeBranch tree == Just (statusBranchRef branch)]

renderRef :: StatusProtocolRef -> BS.ByteString
renderRef ref = protocolStatusName (protocolStatus ref) <>
  maybe "" (" -> " <>) (protocolValue ref) <>
  maybe "" (" (" <>) (fmap (<> ")") (protocolDetail ref))

renderWorktree :: StatusWorktree -> BS.ByteString
renderWorktree tree = "  " <> worktreePath tree <> ": " <> description <>
  if worktreePrunable tree then " (prunable)\n" else "\n"
  where
    description
      | worktreeBare tree = "bare"
      | worktreeDetached tree = "detached"
      | otherwise = maybe "no branch" id (worktreeBranch tree)

count :: [a] -> BS.ByteString
count = BSC.pack . show . length

branchName :: BranchClass -> BS.ByteString
branchName kind = case kind of
  OrdinaryBranch -> "ordinary"
  ValidBranch -> "valid"
  InvalidBranch -> "invalid"
  IndeterminateBranch -> "indeterminate"

protocolStatusName :: ProtocolStatus -> BS.ByteString
protocolStatusName kind = case kind of
  ProtocolMissing -> "missing"
  ProtocolValid -> "valid"
  ProtocolInvalid -> "invalid"
  ProtocolUnknown -> "unknown"
  ProtocolUnreadable -> "unreadable"

hookName :: HookStatus -> BS.ByteString
hookName status = case status of
  HookAbsent -> "absent"
  HookCanonical -> "canonical"
  HookConflict -> "conflict"

hookDetail :: HookStatus -> BS.ByteString
hookDetail status = case status of
  HookAbsent -> "The GAW protection hook is not configured"
  HookCanonical -> "The GAW protection hook is configured"
  HookConflict -> "The gaw-reference-transaction hook configuration is incomplete or divergent"
