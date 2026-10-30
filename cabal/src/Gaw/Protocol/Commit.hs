{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Commit (
    CommitRequest (..),
    CommitReason (..),
    CommitError (..),
    CommitPlan,
    plannedSource,
    plannedTree,
    plannedParents,
    plannedMessage,
    planCommitAt,
    planCommit,
    validateCommitMessage,
    validateChangeBoundary,
    renderCommitError,
) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Layout
import Gaw.Protocol.Ref (ObjectId, RefName)
import Gaw.Protocol.Workspace
import Gaw.Protocol.Workspace.Types (Workspace)

data CommitRequest = CommitRequest
    { requestMessage :: BS.ByteString
    , requestProjectRevisions :: [BS.ByteString]
    , requestAllowEmpty :: Bool
    , requestAllowEmptyMessage :: Bool
    }
    deriving (Eq, Show)

data CommitReason
    = EmptyMessage
    | InvalidCommitMessage
    | NotWorktreeRoot
    | DetachedHead
    | OperationInProgress
    | CommitUnmergedIndex
    | CommitInvalidCommittedState
    | InvalidProjectCommit
    | DuplicateParent
    | InvalidWorkspace
    | PathConflict
    | MixedProtocolChanges
    | EmptyCommit
    | RefMoved
    | GitFailure
    deriving (Eq, Show)

data CommitError = CommitError CommitReason BS.ByteString
    deriving (Eq, Show)

data CommitPlan = CommitPlan
    { plannedSource :: RefName
    , plannedTree :: ObjectId
    , plannedParents :: [ObjectId]
    , plannedMessage :: BS.ByteString
    }
    deriving (Eq, Show)

-- Validate only the title; preserve the complete message's original bytes.
-- The Bool permits a zero-byte message, not a malformed nonempty title.
validateCommitMessage :: BS.ByteString -> Bool -> Either CommitError ()
validateCommitMessage message allowEmptyMessage
    | BS.null message =
        if allowEmptyMessage
            then Right ()
            else Left (CommitError EmptyMessage "The commit message is empty")
    | validTitle = Right ()
    | otherwise =
        Left
            ( CommitError
                InvalidCommitMessage
                ( "Commit subject must follow: type(scope): subject\n"
                    <> "Use printable ASCII, one space after the colon, and no subject edge spaces.\n"
                    <> "Review \"Checkpoint messages\" in the git-agent-workflow skill."
                )
            )
  where
    (line, ending) = BS.break (== 10) message
    title
        | not (BS.null ending) && not (BS.null line) && BS.last line == 13 = BS.init line
        | otherwise = line
    printable byte = byte >= 32 && byte <= 126
    token byte = printable byte && byte `notElem` [32, 40, 41, 58]
    (kind, afterKind) = BS.span token title
    validTitle =
        BS.all printable title
            && not (BS.null kind)
            && case BS.uncons afterKind of
                Just (40, rest) ->
                    let (scope, afterScope) = BS.span token rest
                     in not (BS.null scope)
                            && case BS.stripPrefix "): " afterScope of
                                Just subject ->
                                    not (BS.null subject)
                                        && BS.head subject /= 32
                                        && BS.last subject /= 32
                                Nothing -> False
                _ -> False

-- Paths come from the first-parent/candidate tree diff, not the index inventory.
validateChangeBoundary :: [BS.ByteString] -> Either CommitError ()
validateChangeBoundary paths
    | any inside paths && any (not . inside) paths =
        Left
            ( CommitError
                MixedProtocolChanges
                "A checkpoint cannot change paths both inside and outside .gaw/"
            )
    | otherwise = Right ()
  where
    inside path = path == ".gaw" || ".gaw/" `BS.isPrefixOf` path

planCommit ::
    CommitRequest ->
    RefName ->
    ObjectId ->
    ObjectId ->
    ObjectId ->
    Workspace ->
    [GitEntry] ->
    [(ObjectId, [GitEntry])] ->
    Either CommitError CommitPlan
planCommit = planCommitAt Formal

planCommitAt ::
    HistoryLayout ->
    CommitRequest ->
    RefName ->
    ObjectId ->
    ObjectId ->
    ObjectId ->
    Workspace ->
    [GitEntry] ->
    [(ObjectId, [GitEntry])] ->
    Either CommitError CommitPlan
planCommitAt layout request source firstParent firstTree stagedTree workspace entries projects = do
    validateCommitMessage (requestMessage request) (requestAllowEmptyMessage request)
    checkParents [] (map fst projects)
    case validateWorkspaceAt layout workspace entries of
        Left problem -> Left (CommitError InvalidWorkspace (workspaceDetail problem))
        Right () -> Right ()
    case filter
        ( \(_, projectEntries) ->
            firstProjectPathConflictAt layout workspace projectEntries /= Nothing
        )
        projects of
        [] -> Right ()
        _ ->
            Left
                ( CommitError
                    PathConflict
                    "A project parent tracks a reserved or workspace path"
                )
    if null projects && not (requestAllowEmpty request) && stagedTree == firstTree
        then Left (CommitError EmptyCommit "The staged GAW tree is unchanged")
        else
            Right
                ( CommitPlan
                    source
                    stagedTree
                    (firstParent : map fst projects)
                    (requestMessage request)
                )
  where
    checkParents _ [] = Right ()
    checkParents seen (parent : rest)
        | parent == firstParent =
            Left
                ( CommitError
                    DuplicateParent
                    "A project parent equals the GAW first parent"
                )
        | parent `elem` seen =
            Left
                ( CommitError
                    DuplicateParent
                    "A project parent was supplied more than once"
                )
        | otherwise = checkParents (parent : seen) rest

renderCommitError :: CommitError -> BS.ByteString
renderCommitError (CommitError reason detail) =
    "git-gaw: GAW commit failed (:" <> reasonName reason <> "): " <> detail <> "\n"

reasonName :: CommitReason -> BS.ByteString
reasonName reason = case reason of
    EmptyMessage -> "EMPTY-MESSAGE"
    InvalidCommitMessage -> "INVALID-COMMIT-MESSAGE"
    NotWorktreeRoot -> "NOT-WORKTREE-ROOT"
    DetachedHead -> "DETACHED-HEAD"
    OperationInProgress -> "OPERATION-IN-PROGRESS"
    CommitUnmergedIndex -> "UNMERGED-INDEX"
    CommitInvalidCommittedState -> "INVALID-COMMITTED-STATE"
    InvalidProjectCommit -> "INVALID-PROJECT-COMMIT"
    DuplicateParent -> "DUPLICATE-PARENT"
    InvalidWorkspace -> "INVALID-WORKSPACE"
    PathConflict -> "PATH-CONFLICT"
    MixedProtocolChanges -> "MIXED-PROTOCOL-CHANGES"
    EmptyCommit -> "EMPTY-COMMIT"
    RefMoved -> "REF-MOVED"
    GitFailure -> "RUNTIME-FAILURE"

workspaceDetail :: WorkspaceError -> BS.ByteString
workspaceDetail problem = case problem of
    UnmergedIndex _ -> "The index contains unmerged entries"
    IntentToAdd _ -> "The index contains an intent-to-add entry"
    UnsupportedEntry _ -> "The GAW tree contains an unsupported object"
    WrongDeclaredKind _ -> "A declared workspace path has the wrong Git kind"
    NoncanonicalProtocolPath _ -> "The reserved protocol path has non-canonical spelling"
    OutsideDeclaredWorkspace _ -> "The GAW tree contains a path outside the declared workspace"
