{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Config
  ( Config
  , ConfigError (..)
  , WorkspaceEntry
  , WorkspaceKind (..)
  , WorkspacePath
  , configWorkspace
  , workspaceEntryKind
  , workspaceEntryPath
  , workspacePathText
  , parseConfig
  ) where

import qualified Data.ByteString as BS
import Data.Char (ord)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

data ConfigError
  = InvalidSyntax T.Text
  | InvalidSchema T.Text
  | LimitExceeded T.Text
  deriving (Eq, Show)

data WorkspaceKind = WorkspaceFile | WorkspaceDirectory
  deriving (Eq, Show)

newtype WorkspacePath = WorkspacePath T.Text
  deriving (Eq, Ord, Show)

data WorkspaceEntry = WorkspaceEntry WorkspaceKind WorkspacePath
  deriving (Eq, Show)

newtype Config = Config [WorkspaceEntry]
  deriving (Eq, Show)

configWorkspace :: Config -> [WorkspaceEntry]
configWorkspace (Config entries) = entries

workspaceEntryKind :: WorkspaceEntry -> WorkspaceKind
workspaceEntryKind (WorkspaceEntry kind _) = kind

workspaceEntryPath :: WorkspaceEntry -> WorkspacePath
workspaceEntryPath (WorkspaceEntry _ path) = path

workspacePathText :: WorkspacePath -> T.Text
workspacePathText (WorkspacePath path) = path

data Form = FormList [Form] | FormKeyword T.Text | FormString T.Text
  deriving (Eq, Show)

parseConfig :: BS.ByteString -> Either ConfigError Config
parseConfig bytes
  | BS.length bytes > 65536 = Left (LimitExceeded "Config exceeds 65536 octets")
  | otherwise = do
      input <- either (const (Left (InvalidSyntax "Config is not valid UTF-8"))) Right
        (TE.decodeUtf8' bytes)
      if T.isPrefixOf "\xfeff" input
        then Left (InvalidSyntax "UTF-8 BOM is not allowed")
        else do
          (form, rest) <- parseForm 0 (skipTrivia (T.unpack input))
          if null (skipTrivia rest)
            then configFromForm form
            else Left (InvalidSyntax "Config contains multiple forms")

parseForm :: Int -> String -> Either ConfigError (Form, String)
parseForm _ [] = Left (InvalidSyntax "Config is empty or incomplete")
parseForm depth ('(':rest)
  | depth >= 16 = Left (LimitExceeded "List nesting exceeds 16")
  | otherwise = parseList (depth + 1) [] rest
parseForm _ (')':_) = Left (InvalidSyntax "Unmatched closing parenthesis")
parseForm _ ('"':rest) = parseString [] rest
parseForm _ input =
  let (token, rest) = span (not . delimiter) input
   in case token of
        ":workspace" -> Right (FormKeyword "workspace", rest)
        ":file" -> Right (FormKeyword "file", rest)
        ":directory" -> Right (FormKeyword "directory", rest)
        ':':_ -> Left (InvalidSchema "Unknown config keyword")
        _ -> Left (InvalidSyntax "Unsupported token")

parseList :: Int -> [Form] -> String -> Either ConfigError (Form, String)
parseList depth acc input = case skipTrivia input of
  [] -> Left (InvalidSyntax "Unclosed list")
  ')':rest -> Right (FormList (reverse acc), rest)
  rest -> do
    (form, next) <- parseForm depth rest
    parseList depth (form : acc) next

parseString :: [Char] -> String -> Either ConfigError (Form, String)
parseString _ [] = Left (InvalidSyntax "Unterminated string")
parseString acc ('"':rest) = Right (FormString (T.pack (reverse acc)), rest)
parseString acc ('\\':escaped:rest)
  | escaped == '"' || escaped == '\\' = parseString (escaped : acc) rest
  | otherwise = Left (InvalidSyntax "Unsupported string escape")
parseString _ ['\\'] = Left (InvalidSyntax "Incomplete string escape")
parseString acc (c:rest)
  | ord c < 32 || ord c == 127 = Left (InvalidSyntax "Literal ASCII control character in string")
  | otherwise = parseString (c : acc) rest

delimiter :: Char -> Bool
delimiter c = c `elem` (" \t\n\r();" :: String)

skipTrivia :: String -> String
skipTrivia input = case input of
  c:rest | c `elem` (" \t\n\r" :: String) -> skipTrivia rest
  ';':rest -> skipTrivia (dropWhile (/= '\n') rest)
  _ -> input

configFromForm :: Form -> Either ConfigError Config
configFromForm (FormList [FormKeyword "workspace", FormList forms]) = do
  if length forms > 1024
    then Left (LimitExceeded "Workspace contains more than 1024 entries")
    else do
      entries <- traverse entryFromForm forms
      let paths = map workspaceEntryPath entries
      if Set.size (Set.fromList paths) == length paths
        then Right (Config entries)
        else Left (InvalidSchema "Duplicate workspace path")
configFromForm _ = Left (InvalidSchema "Expected exactly one :workspace form")

entryFromForm :: Form -> Either ConfigError WorkspaceEntry
entryFromForm (FormList [FormKeyword kind, FormString text]) = do
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
