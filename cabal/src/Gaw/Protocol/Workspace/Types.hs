module Gaw.Protocol.Workspace.Types
  ( Workspace (..)
  , WorkspaceEntry (..)
  , WorkspaceKind (..)
  , WorkspacePath (..)
  , workspaceEntryKind
  , workspaceEntryPath
  , workspacePathText
  ) where

import qualified Data.Text as T

newtype Workspace = Workspace { workspaceEntries :: [WorkspaceEntry] }
  deriving (Eq, Show)

data WorkspaceKind = WorkspaceFile | WorkspaceDirectory
  deriving (Eq, Show)

newtype WorkspacePath = WorkspacePath T.Text
  deriving (Eq, Ord, Show)

data WorkspaceEntry = WorkspaceEntry WorkspaceKind WorkspacePath
  deriving (Eq, Show)

workspaceEntryKind :: WorkspaceEntry -> WorkspaceKind
workspaceEntryKind (WorkspaceEntry kind _) = kind

workspaceEntryPath :: WorkspaceEntry -> WorkspacePath
workspaceEntryPath (WorkspaceEntry _ path) = path

workspacePathText :: WorkspacePath -> T.Text
workspacePathText (WorkspacePath path) = path

