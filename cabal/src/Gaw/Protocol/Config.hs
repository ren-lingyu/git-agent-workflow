{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Config
  ( Config
  , ConfigError (..)
  , WorkspaceEntry
  , WorkspaceKind (..)
  , WorkspacePath
  , configWorkspace
  , effectiveWorkspace
  , workspaceEntryKind
  , workspaceEntryPath
  , workspacePathText
  , parseConfig
  , decodeConfig
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Workspace.Types
import Gaw.Protocol.SExpr
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

data ConfigError
  = InvalidSyntax T.Text
  | InvalidSchema T.Text
  | LimitExceeded T.Text
  deriving (Eq, Show)

newtype Config = Config [WorkspaceEntry]
  deriving (Eq, Show)

configWorkspace :: Config -> [WorkspaceEntry]
configWorkspace (Config entries) = entries

effectiveWorkspace :: Config -> Workspace
effectiveWorkspace = Workspace . configWorkspace

parseConfig :: BS.ByteString -> Either ConfigError Config
parseConfig bytes = do
  form <- either (Left . syntaxError) Right (parseSExpr bytes)
  decodeConfig form
  where
    syntaxError (SyntaxError detail) = InvalidSyntax detail
    syntaxError (SyntaxLimit detail) = LimitExceeded detail

decodeConfig :: SExpr -> Either ConfigError Config
decodeConfig form = do
  checkKeywords form
  configFromForm form
  where
    checkKeywords (SList forms) = mapM_ checkKeywords forms
    checkKeywords (SKeyword keyword)
      | keyword `notElem` ["workspace", "file", "directory"] =
          Left (InvalidSchema "Unknown config keyword")
    checkKeywords _ = Right ()

configFromForm :: SExpr -> Either ConfigError Config
configFromForm (SList [SKeyword "workspace", SList forms]) = do
  if length forms > 1024
    then Left (LimitExceeded "Workspace contains more than 1024 entries")
    else do
      entries <- traverse entryFromForm forms
      let paths = map workspaceEntryPath entries
      if Set.size (Set.fromList paths) == length paths
        then Right (Config entries)
        else Left (InvalidSchema "Duplicate workspace path")
configFromForm _ = Left (InvalidSchema "Expected exactly one :workspace form")

entryFromForm :: SExpr -> Either ConfigError WorkspaceEntry
entryFromForm (SList [SKeyword kind, SString text]) = do
  checkedKind <- case kind of
    "file" -> Right WorkspaceFile
    "directory" -> Right WorkspaceDirectory
    _ -> Left (InvalidSchema "Workspace entry has an invalid kind")
  path <- validatePath text
  Right (WorkspaceEntry checkedKind path)
entryFromForm _ = Left (InvalidSchema "Workspace entry must contain kind and path")

validatePath :: T.Text -> Either ConfigError WorkspacePath
validatePath path
  | T.null path = Left (InvalidSchema "Workspace path is empty")
  | BS.length (TE.encodeUtf8 path) > 4096 = Left (LimitExceeded "Workspace path exceeds 4096 UTF-8 octets")
  | T.head path == '/' || T.last path == '/' = Left (InvalidSchema "Workspace path is not relative and canonical")
  | T.any (== '\\') path = Left (InvalidSchema "Workspace path contains a backslash")
  | any invalidComponent components = Left (InvalidSchema "Workspace path contains an invalid component")
  | reservedComponent components =
      Left (InvalidSchema "Workspace path uses a reserved component")
  | otherwise = Right (WorkspacePath path)
  where
    components = T.splitOn "/" path
    invalidComponent c = T.null c || c == "." || c == ".."

reservedComponent :: [T.Text] -> Bool
reservedComponent [] = False
reservedComponent (first:components) =
  asciiFold first == ".gaw" || any ((== ".git") . asciiFold) (first : components)

asciiFold :: T.Text -> T.Text
asciiFold = T.map lowerAscii
  where
    lowerAscii c
      | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
      | otherwise = c
