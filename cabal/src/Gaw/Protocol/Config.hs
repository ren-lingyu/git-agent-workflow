{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Config
  ( Config
  , ConfigError (..)
  , VersionRecognition (..)
  , ConfigVersion (..)
  , WorkspaceSection (..)
  , ConfigWarning (..)
  , configVersion
  , configSections
  , configWarnings
  , renderConfigWarning
  , unsupportedVersionDetail
  , unrecognizedVersionDetail
  , WorkspaceEntry
  , WorkspaceKind (..)
  , WorkspacePath
  , configWorkspace
  , effectiveWorkspace
  , workspaceEntryKind
  , workspaceEntryPath
  , workspacePathText
  , parseConfig
  , recognizeConfigVersion
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
  | UnsupportedVersion Integer
  | UnrecognizedVersion BS.ByteString
  deriving (Eq, Show)

data VersionRecognition
  = LegacyConfig
  | NumericVersion Integer
  | OpaqueVersion BS.ByteString
  deriving (Eq, Show)

data ConfigVersion = ConfigV0 | ConfigV1
  deriving (Eq, Show)

data WorkspaceSection
  = DirectEntry WorkspaceEntry
  | RoleGroup T.Text [WorkspaceEntry]
  deriving (Eq, Show)

newtype ConfigWarning = UnknownTopLevelField T.Text
  deriving (Eq, Show)

data Config = Config
  { configVersion :: ConfigVersion
  , configSections :: [WorkspaceSection]
  , configWarnings :: [ConfigWarning]
  } deriving (Eq, Show)

configWorkspace :: Config -> [WorkspaceEntry]
configWorkspace = concatMap entries . configSections
  where
    entries (DirectEntry entry) = [entry]
    entries (RoleGroup _ paths) = paths

effectiveWorkspace :: Config -> Workspace
effectiveWorkspace = Workspace . configWorkspace

renderConfigWarning :: ConfigWarning -> BS.ByteString
renderConfigWarning (UnknownTopLevelField name) =
  "Ignoring unknown top-level config field :" <> TE.encodeUtf8 name

unsupportedVersionDetail :: Integer -> BS.ByteString
unsupportedVersionDetail version =
  "Unsupported config version " <> TE.encodeUtf8 (T.pack (show version))

unrecognizedVersionDetail :: BS.ByteString -> BS.ByteString
unrecognizedVersionDetail token =
  "Unrecognized config version " <> BS.concatMap escape (BS.take 64 token) <>
  (if BS.length token > 64 then "..." else "")
  where
    escape byte
      | byte >= 33 && byte <= 126 && byte /= 92 = BS.singleton byte
      | otherwise = TE.encodeUtf8 (T.pack ("\\x" <> hexByte byte))
    hexByte byte = [hexDigit (byte `div` 16), hexDigit (byte `mod` 16)]
    hexDigit nibble = "0123456789ABCDEF" !! fromIntegral nibble

recognizeConfigVersion :: BS.ByteString -> Either ConfigError VersionRecognition
recognizeConfigVersion bytes = do
  envelope <- either (Left . syntaxError) Right (scanLeadingVersion bytes)
  case envelope of
    NoLeadingVersion -> Right LegacyConfig
    MalformedLeadingVersion -> Left malformedVersion
    LeadingVersionAtom atom
      | T.all asciiDigit atom -> Right (NumericVersion (read (T.unpack atom)))
      | T.head atom == ':' || negativeInteger atom -> Left malformedVersion
      | otherwise -> Right (OpaqueVersion (TE.encodeUtf8 atom))
  where
    asciiDigit c = c >= '0' && c <= '9'
    negativeInteger atom = case T.uncons atom of
      Just ('-', rest) -> not (T.null rest) && T.all asciiDigit rest
      _ -> False
    malformedVersion = InvalidSchema "Config version must be a non-negative integer"

syntaxError :: SyntaxError -> ConfigError
syntaxError (SyntaxError detail) = InvalidSyntax detail
syntaxError (SyntaxLimit detail) = LimitExceeded detail

parseConfig :: BS.ByteString -> Either ConfigError Config
parseConfig bytes = do
  recognition <- recognizeConfigVersion bytes
  case recognition of
    LegacyConfig -> decodeKnownConfig
    NumericVersion 0 -> decodeKnownConfig
    NumericVersion 1 -> decodeKnownConfig
    NumericVersion version -> Left (UnsupportedVersion version)
    OpaqueVersion token -> Left (UnrecognizedVersion token)
  where
    decodeKnownConfig = do
      form <- either (Left . syntaxError) Right (parseSExpr bytes)
      decodeConfig form

decodeConfig :: SExpr -> Either ConfigError Config
decodeConfig form = do
  fields <- plist form
  version <- case lookup "version" fields of
    Nothing -> Right ConfigV0
    Just (SInteger 0) -> Right ConfigV0
    Just (SInteger 1) -> Right ConfigV1
    Just (SInteger number) | number >= 0 -> Left (UnsupportedVersion number)
    _ -> Left (InvalidSchema "Config version must be a non-negative integer")
  let unknown = [name | (name, _) <- fields, name `notElem` ["version", "workspace"]]
  if version == ConfigV0 && not (null unknown)
    then Left (InvalidSchema "Unknown config keyword")
    else pure ()
  forms <- case lookup "workspace" fields of
    Just (SList entries) -> Right entries
    _ -> Left (InvalidSchema "Expected a :workspace list")
  sections <- traverse (sectionFromForm version) forms
  let config = Config version sections (map UnknownTopLevelField unknown)
      entries = configWorkspace config
      paths = map workspaceEntryPath entries
  if length entries > 1024
    then Left (LimitExceeded "Workspace contains more than 1024 entries")
    else if Set.size (Set.fromList paths) /= length paths
      then Left (InvalidSchema "Duplicate workspace path")
      else Right config

plist :: SExpr -> Either ConfigError [(T.Text, SExpr)]
plist (SList forms) = go Set.empty forms
  where
    go _ [] = Right []
    go seen (SKeyword key:value:rest)
      | not (validName key) = Left (InvalidSchema "Invalid top-level config keyword")
      | key `Set.member` seen = Left (InvalidSchema "Duplicate top-level config key")
      | otherwise = ((key, value) :) <$> go (Set.insert key seen) rest
    go _ _ = Left (InvalidSchema "Config must be a keyword/value plist")
plist _ = Left (InvalidSchema "Config must be a keyword/value plist")

sectionFromForm :: ConfigVersion -> SExpr -> Either ConfigError WorkspaceSection
sectionFromForm ConfigV1 (SList [SKeyword role, SList forms])
  | role `notElem` ["file", "directory"] && validName role =
      RoleGroup role <$> traverse entryFromForm forms
sectionFromForm _ form = DirectEntry <$> entryFromForm form

entryFromForm :: SExpr -> Either ConfigError WorkspaceEntry
entryFromForm (SList [SKeyword kind, SString text]) = do
  checkedKind <- case kind of
    "file" -> Right WorkspaceFile
    "directory" -> Right WorkspaceDirectory
    _ -> Left (InvalidSchema "Workspace entry has an invalid kind")
  path <- validatePath text
  Right (WorkspaceEntry checkedKind path)
entryFromForm _ = Left (InvalidSchema "Workspace entry must contain kind and path")

validName :: T.Text -> Bool
validName name = case T.uncons name of
  Just (first, rest) -> lower first && T.all continuation rest
  Nothing -> False
  where
    lower c = c >= 'a' && c <= 'z'
    continuation c = lower c || (c >= '0' && c <= '9') || c == '-'

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
