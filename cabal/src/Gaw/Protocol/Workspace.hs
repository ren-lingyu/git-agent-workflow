{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Workspace
  ( GitEntry (..)
  , WorkspaceError (..)
  , validateSnapshot
  , validateWorkspace
  , firstProjectPathConflict
  , synthesizeIndexDirectories
  ) where

import qualified Data.ByteString as BS
import qualified Data.Text.Encoding as TE
import Gaw.Protocol.Config

data GitEntry = GitEntry
  { entryMode :: BS.ByteString
  , entryType :: BS.ByteString
  , entryObjectId :: BS.ByteString
  , entryPath :: BS.ByteString
  , entryStage :: Int
  , entryIntentToAdd :: Bool
  } deriving (Eq, Show)

data WorkspaceError
  = UnmergedIndex BS.ByteString
  | IntentToAdd BS.ByteString
  | UnsupportedEntry BS.ByteString
  | WrongDeclaredKind BS.ByteString
  | NoncanonicalProtocolPath BS.ByteString
  | OutsideDeclaredWorkspace BS.ByteString
  deriving (Eq, Show)

validateSnapshot :: [GitEntry] -> Either WorkspaceError ()
validateSnapshot = mapM_ check
  where
    check entry
      | entryStage entry > 0 = Left (UnmergedIndex (entryPath entry))
      | entryIntentToAdd entry || zeroObjectId (entryObjectId entry) = Left (IntentToAdd (entryPath entry))
      | not (isTree entry || isFile entry) = Left (UnsupportedEntry (entryPath entry))
      | otherwise = Right ()

validateWorkspace :: Config -> [GitEntry] -> Either WorkspaceError ()
validateWorkspace config entries = do
  validateSnapshot entries
  mapM_ checkDeclared declarations
  mapM_ checkEntry entries
  where
    declarations = map declaration (configWorkspace config)
    checkDeclared (kind, path) = case findEntry path entries of
      Nothing -> Right ()
      Just entry
        | kind == WorkspaceFile && isFile entry -> Right ()
        | kind == WorkspaceDirectory && isTree entry -> Right ()
        | otherwise -> Left (WrongDeclaredKind path)
    checkEntry entry
      | isCanonicalProtocolPath path = Right ()
      | isReservedProtocolPath path = Left (NoncanonicalProtocolPath path)
      | any (`covers` entry) declarations = Right ()
      | otherwise = Left (OutsideDeclaredWorkspace path)
      where path = entryPath entry

firstProjectPathConflict :: Config -> [GitEntry] -> Maybe BS.ByteString
firstProjectPathConflict config entries = case filter conflicts entries of
  entry : _ -> Just (entryPath entry)
  [] -> Nothing
  where
    declarations = map declaration (configWorkspace config)
    conflicts entry = isReservedProtocolPath path
      || any (projectConflict entry) declarations
      where path = entryPath entry

synthesizeIndexDirectories :: [GitEntry] -> [GitEntry]
synthesizeIndexDirectories entries = entries ++ missing
  where
    paths = map entryPath entries
    parents = concatMap (parentPaths . entryPath) entries
    missingPaths = unique [path | path <- parents, path `notElem` paths]
    missing = [GitEntry "040000" "tree" "" path 0 False | path <- missingPaths]

declaration :: WorkspaceEntry -> (WorkspaceKind, BS.ByteString)
declaration entry = (workspaceEntryKind entry, TE.encodeUtf8 (workspacePathText (workspaceEntryPath entry)))

findEntry :: BS.ByteString -> [GitEntry] -> Maybe GitEntry
findEntry path = go
  where
    go [] = Nothing
    go (entry:rest)
      | entryPath entry == path = Just entry
      | otherwise = go rest

covers :: (WorkspaceKind, BS.ByteString) -> GitEntry -> Bool
covers (kind, declaredPath) entry
  | isTree entry = (kind == WorkspaceDirectory
      && (declaredPath == path || pathPrefix declaredPath path))
      || pathPrefix path declaredPath
  | otherwise = (kind == WorkspaceFile && declaredPath == path)
      || (kind == WorkspaceDirectory && pathPrefix declaredPath path)
  where path = entryPath entry

projectConflict :: GitEntry -> (WorkspaceKind, BS.ByteString) -> Bool
projectConflict entry (_, declaredPath)
  | isTree entry = path == declaredPath || pathPrefix declaredPath path
  | otherwise = path == declaredPath || pathPrefix path declaredPath
      || pathPrefix declaredPath path
  where path = entryPath entry

isTree :: GitEntry -> Bool
isTree entry = entryMode entry == "040000" && entryType entry == "tree"

isFile :: GitEntry -> Bool
isFile entry = entryMode entry `elem` ["100644", "100755", "120000"]
  && entryType entry == "blob"

zeroObjectId :: BS.ByteString -> Bool
zeroObjectId oid = not (BS.null oid) && BS.all (== 48) oid

isCanonicalProtocolPath :: BS.ByteString -> Bool
isCanonicalProtocolPath path = path == ".gaw" || pathPrefix ".gaw" path

isReservedProtocolPath :: BS.ByteString -> Bool
isReservedProtocolPath path = asciiLower (BS.takeWhile (/= 47) path) == ".gaw"

asciiLower :: BS.ByteString -> BS.ByteString
asciiLower = BS.map lower
  where lower c | c >= 65 && c <= 90 = c + 32
                | otherwise = c

pathPrefix :: BS.ByteString -> BS.ByteString -> Bool
pathPrefix prefix path = BS.length path > BS.length prefix
  && prefix `BS.isPrefixOf` path
  && BS.index path (BS.length prefix) == 47

parentPaths :: BS.ByteString -> [BS.ByteString]
parentPaths path = [BS.take index path | index <- BS.elemIndices 47 path]

unique :: Eq a => [a] -> [a]
unique = foldr (\item rest -> if item `elem` rest then rest else item : rest) []
