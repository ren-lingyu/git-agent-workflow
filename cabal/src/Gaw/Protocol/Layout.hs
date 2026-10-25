{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Layout (
    HistoryLayout (..),
    auxiliaryUuid,
    auxiliaryReserved,
    layoutForRef,
    configPath,
    logicalPaths,
    validateWorkspaceAt,
    firstProjectPathConflictAt,
) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Ref
import Gaw.Protocol.Workspace
import Gaw.Protocol.Workspace.Types (Workspace)

data HistoryLayout = Formal | Auxiliary BS.ByteString deriving (Eq, Show)

auxiliaryReserved :: RefName -> Bool
auxiliaryReserved = BS.isPrefixOf "refs/heads/_gaw_aux_" . refNameBytes

auxiliaryUuid :: RefName -> Maybe BS.ByteString
auxiliaryUuid ref
    | auxiliaryReserved ref && valid uuid = Just uuid
    | otherwise = Nothing
  where
    uuid = BS.drop (BS.length "refs/heads/_gaw_aux_") (refNameBytes ref)
    valid value =
        BS.length value == 36
            && and
                [ if i `elem` [8, 13, 18, 23]
                    then c == 45
                    else
                        if i == 14
                            then c == 52
                            else
                                if i == 19
                                    then c `elem` [56, 57, 97, 98]
                                    else (c >= 48 && c <= 57) || (c >= 97 && c <= 102)
                | (i, c) <- zip [0 :: Int ..] (BS.unpack value)
                ]

layoutForRef :: RefName -> HistoryLayout
layoutForRef = maybe Formal Auxiliary . auxiliaryUuid

configPath :: HistoryLayout -> BS.ByteString
configPath Formal = ".gaw/config"
configPath (Auxiliary uuid) = uuid <> "/.gaw/config"

logicalPaths :: HistoryLayout -> [BS.ByteString] -> [BS.ByteString]
logicalPaths Formal = id
logicalPaths (Auxiliary uuid) = map $ \path ->
    maybe path id (BS.stripPrefix (uuid <> "/") path)

validateWorkspaceAt :: HistoryLayout -> Workspace -> [GitEntry] -> Either WorkspaceError ()
validateWorkspaceAt Formal = validateWorkspace
validateWorkspaceAt (Auxiliary uuid) = \workspace entries -> do
    validateSnapshot entries
    mapM_ boundary entries
    validateWorkspace workspace (children entries)
  where
    boundary entry
        | entryPath entry == uuid && entryMode entry == "040000" && entryType entry == "tree" = Right ()
        | (uuid <> "/") `BS.isPrefixOf` entryPath entry = Right ()
        | otherwise = Left (OutsideDeclaredWorkspace (entryPath entry))
    children entries =
        [ entry{entryPath = BS.drop (BS.length uuid + 1) (entryPath entry)}
        | entry <- entries
        , (uuid <> "/") `BS.isPrefixOf` entryPath entry
        ]

-- Compare physical paths. An unrelated root .gaw/ in an external parent is
-- harmless to an Auxiliary workspace; a file occupying its UUID is not.
firstProjectPathConflictAt :: HistoryLayout -> Workspace -> [GitEntry] -> Maybe BS.ByteString
firstProjectPathConflictAt Formal = firstProjectPathConflict
firstProjectPathConflictAt (Auxiliary uuid) = \workspace entries ->
    case [ entryPath entry
         | entry <- entries
         , entryPath entry == uuid
         , entryType entry /= "tree"
         ] of
        path : _ -> Just path
        [] ->
            fmap
                ((uuid <> "/") <>)
                ( firstProjectPathConflict
                    workspace
                    [ entry{entryPath = BS.drop (BS.length uuid + 1) (entryPath entry)}
                    | entry <- entries
                    , (uuid <> "/") `BS.isPrefixOf` entryPath entry
                    ]
                )
