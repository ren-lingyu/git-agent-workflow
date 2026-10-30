{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.Text as DataText
import qualified Data.Text.Encoding as TE
import Gaw.Protocol.Commit (CommitError (..), CommitReason (..), CommitRequest (..), planCommitAt, plannedMessage, renderCommitError, validateChangeBoundary, validateCommitMessage)
import Gaw.Protocol.Config
import Gaw.Protocol.Deploy
import Gaw.Protocol.Hook
import Gaw.Protocol.Init (defaultConfig, initialConfig)
import Gaw.Protocol.Layout
import Gaw.Protocol.Ref
import Gaw.Protocol.SExpr
import Gaw.Protocol.Show
import Gaw.Protocol.Status (StatusWorktree (..))
import Gaw.Protocol.Workspace
import Gaw.Protocol.Workspace.Types (Workspace (..))
import Gaw.System.Entropy (uuidV4)
import Gaw.System.Repository
import System.Exit (exitFailure)

assert :: Bool -> IO ()
assert True = pure ()
assert False = exitFailure

main :: IO ()
main = do
    assert $ parseSExpr "(:custom ())" == Right (SList [SKeyword "custom", SList []])
    assert $
        decodeConfig (SList [SKeyword "custom", SList []])
            == Left (InvalidSchema "Unknown config keyword")
    let parsed = parseConfig "(:workspace ((:file \"a\\\"b\") (:directory \"memory\")))"
    assert $ case parsed of
        Right config -> length (configWorkspace config) == 2
        Left _ -> False
    assert $ case parseConfig "(:workspace ())" of
        Right config -> null (configWorkspace config)
        Left _ -> False
    mapM_
        (assertCase invalidSyntax)
        [ ""
        , "(:workspace ()) (:workspace ())"
        , "#.(error \"unsafe\")"
        , "(:workspace ((:file \"bad\\npath\")))"
        , "(:workspace ((:file \"line\nbreak\")))"
        , "(:workspace nil)"
        , BS.pack [0xef, 0xbb, 0xbf]
        , BS.pack [0xff]
        ]
    mapM_
        (assertCase invalidSchema)
        [ "(:workspace () :workspace ())"
        , "(:workspace ((:file \"a\") (:directory \"a\")))"
        , "(:workspace ((:file \"a/../b\")))"
        , "(:workspace ((:file \".GAW/config\")))"
        , "(:workspace ((:file \"a/.GiT/b\")))"
        , "(:workspace () :unknown ())"
        ]
    assert $ isLimit (parseConfig (BS.replicate 65537 32))
    assert $ isLimit (parseConfig (TE.encodeUtf8 "(:workspace ((:file \"" <> mconcat (replicate 4097 "a") <> "\")))"))
    assert $ parseHookPhase "preparing" == Right Preparing
    assert $ parseHookPhase "future" == Left (InvalidPhase "future")
    let updates = parseReferenceTransaction "0000 1111 refs/heads/gaw\n"
    assert $ case updates of
        Right [update] -> updateRef update == "refs/heads/gaw"
        _ -> False
    mapM_
        (assert . invalidHookInput . parseReferenceTransaction)
        ["\n", "0 1", "0 1 refs/heads/gaw extra", "not-an-oid 1 refs/heads/gaw"]
    let update = RefUpdate (ObjectValue "0000") (ObjectValue "1111") "refs/heads/gaw"
        oldMarker = MarkerObservation "100644 blob marker" ValidCommitted Nothing
    assert $
        checkProtectedSource update "refs/heads/gaw" (SourceDirect "aaaa" (Just oldMarker))
            == Left (ProtectedRef "refs/heads/gaw")
    assert $ checkProtectedSource update "refs/heads/new" (SourceDirect "aaaa" Nothing) == Right ()
    assert $
        protectProtocolRef (update{updateRef = "refs/gaw/HEAD"})
            == Left (ProtectedProtocolRef "refs/gaw/HEAD")
    assert $ case parseSourceRef "refs/heads/agents" of
        Right source -> isSourceRef source && refNameBytes source == "refs/heads/agents"
        Left _ -> False
    mapM_
        (assert . invalidRef . parseRefName)
        ["", "@", "refs//heads/a", "refs/heads/.hidden", "refs/heads/a.lock", "refs/heads/a..b", "refs/heads/a b", "refs/heads/a@{b"]
    assert $ parseSourceRef "refs/gaw/HEAD" == Left (NotSourceRef "refs/gaw/HEAD")
    assert $ case parseRefName "refs/heads/agents" of
        Right source -> classifySelector (RefSymbolic source) == SelectorSelected source
        Left _ -> False
    assert $ classifySelector RefMissing == SelectorMissing
    assert $ case parseObjectId (BS.replicate 40 97) of
        Right oid -> objectIdBytes oid == BS.replicate 40 97
        Left _ -> False
    let config = parseConfig "(:workspace ((:directory \"memory\")))"
        nonUtfPath = BS.concat ["memory/", BS.pack [255]]
        file = GitEntry "100644" "blob" (BS.replicate 40 97) nonUtfPath 0 False
        outside = file{entryPath = "outside"}
    assert $ case config of
        Right value ->
            validateWorkspace (effectiveWorkspace value) (synthesizeIndexDirectories [file]) == Right ()
                && validateWorkspace (effectiveWorkspace value) [outside] == Left (OutsideDeclaredWorkspace "outside")
                && firstProjectPathConflict (effectiveWorkspace value) [file] == Just nonUtfPath
        Left _ -> False
    assert $ validateSnapshot [file{entryStage = 2}] == Left (UnmergedIndex nonUtfPath)
    assert $ validateSnapshot [file{entryIntentToAdd = True}] == Left (IntentToAdd nonUtfPath)
    assert $ case config of
        Right value ->
            validateWorkspace (effectiveWorkspace value) [file{entryPath = ".GAW/config"}]
                == Left (NoncanonicalProtocolPath ".GAW/config")
        Left _ -> False
    assert $
        prepareShowArguments ["--no-diff-merges", "--", "-m"]
            == Right ["show", "--no-diff-merges", "--first-parent", "--", "-m"]
    assert $
        prepareShowArguments ["--diff-merges=off", "--dd"]
            == Right ["show", "--diff-merges=off", "--dd", "--first-parent", "--diff-merges=first-parent"]
    assert $ prepareShowArguments ["--cc"] == Left (UnsupportedOption "--cc")
    let rawPath = BS.pack [109, 101, 109, 111, 114, 121, 47, 255]
        record = BS.concat ["100644 ", BS.replicate 40 97, " 0\t", rawPath, "\0"]
    assert $ case parseIndexRecords record of
        Right [entry] -> entryPath entry == rawPath && entryStage entry == 0
        _ -> False
    assert $ parseIndexRecords (BS.init record) == Left UnterminatedRecord
    assert $ case parseTreeRecords (BS.concat ["100644 blob ", BS.replicate 40 97, "\t", rawPath, "\0"]) of
        Right [entry] -> entryPath entry == rawPath && entryType entry == "blob"
        _ -> False
    let attached = StatusWorktree "/tmp/agent" (Just "refs/heads/gaw") False False False
        other = StatusWorktree "/tmp/other" (Just "refs/heads/main") False False False
    assert $
        planWorktree "refs/heads/gaw" Nothing False [attached]
            == Right (ExistingWorktree "/tmp/agent")
    assert $
        planWorktree "refs/heads/gaw" (Just "/tmp/agent/") False [attached]
            == Right (ExistingWorktree "/tmp/agent/")
    assert $
        planWorktree "refs/heads/gaw" (Just "/tmp/other") False [other]
            == Left (PathAttachedElsewhere "/tmp/other")
    assert $
        planWorktree "refs/heads/gaw" (Just "/tmp/new") False [attached]
            == Left (BranchAlreadyAttached "refs/heads/gaw" "/tmp/agent")
    assert $
        planWorktree "refs/heads/gaw" (Just "/tmp/new") True []
            == Left (PathOccupied "/tmp/new")
    assert (uuidV4 (BS.replicate 16 255) == Just "ffffffff-ffff-4fff-bfff-ffffffffffff")
    assert (uuidV4 "short" == Nothing)
    layoutTests
    versionedConfigTests
    commitBoundaryTests
    commitMessageTests
    initialConfigTests
    putStrLn "Protocol tests passed"

invalidSyntax :: Either ConfigError a -> Bool
invalidSyntax (Left (InvalidSyntax _)) = True
invalidSyntax _ = False

initialConfigTests :: IO ()
initialConfigTests = do
    resource <- BS.readFile "resources/default-config.txt"
    assert (defaultConfig == resource)
    assert
        ( defaultConfig
            == "(:version 1\n :workspace ((:archive ((:directory \"archive\")))\n             (:memory ((:directory \"memory\")))\n             (:skills ((:directory \"skills\")))))\n"
        )
    case (parseConfig initialConfig, parseConfig defaultConfig) of
        (Right empty, Right preset) -> do
            -- Both initialization modes must track the CLI's current generated schema.
            assert (configVersion preset == configVersion empty)
            assert (null (configWarnings preset))
            assert $ case configSections preset of
                [RoleGroup "archive" [_], RoleGroup "memory" [_], RoleGroup "skills" [_]] -> True
                _ -> False
            assert (map (workspacePathText . workspaceEntryPath) (configWorkspace preset) == ["archive", "memory", "skills"])
            assert (all ((== WorkspaceDirectory) . workspaceEntryKind) (configWorkspace preset))
        _ -> assert False

commitMessageTests :: IO ()
commitMessageTests = do
    let valid =
            [ "chore(memory): record state"
            , "custom(scope): subject\n"
            , "custom-type(skills/example): subject (with): details\r\n\r\nBody\nTrailer: value\n"
            , "fix(custom-scope): subject\n\n" <> BS.pack [0, 9, 13, 127, 255]
            , "x(y): z"
            ]
        invalid =
            [ "free form"
            , "(scope): subject"
            , "type(): subject"
            , "type(scope): "
            , "type(scope):"
            , "type(scope):subject"
            , "type(scope):  subject"
            , "type(scope): subject "
            , "type(scope):   "
            , "type(scope): \t"
            , " type(scope): subject"
            , "ty pe(scope): subject"
            , "type(sc ope): subject"
            , "type(scope) subject"
            , "type scope: subject"
            , "type((scope)): subject"
            , "type(scope:extra): subject"
            , "type(scope)!: subject"
            , "type(scope): subject\r"
            , "type(scope): subject\r\r\n"
            , "type(scope): sub\rject\n"
            , "\nchore(memory): subject"
            , "\r\n"
            , " "
            , "\t"
            , TE.encodeUtf8 "chore(memory): 中文标题"
            ]
                ++ ["type(scope): sub" <> BS.singleton byte <> "ject" | byte <- [0, 9, 31, 127, 128, 255]]
    mapM_ (\message -> assert (validateCommitMessage message False == Right ())) valid
    mapM_
        (\message -> mapM_ (assert . invalidMessage . validateCommitMessage message) [False, True])
        invalid
    assert (validateCommitMessage "" True == Right ())
    assert (validateCommitMessage "" False == Left (CommitError EmptyMessage "The commit message is empty"))
    assert $ case validateCommitMessage "bad" False of
        Left problem ->
            all
                (`BS.isInfixOf` renderCommitError problem)
                [":INVALID-COMMIT-MESSAGE", "type(scope): subject", "Checkpoint messages", "git-agent-workflow skill"]
        Right () -> False
    case (parseSourceRef "refs/heads/agents", parseObjectId (BS.replicate 40 97)) of
        (Right source, Right oid) -> do
            let plan message allow =
                    planCommitAt Formal (CommitRequest message [] True allow) source oid oid oid (Workspace []) [] []
            mapM_
                (\message -> assert $ case plan message False of Right result -> plannedMessage result == message; _ -> False)
                valid
            mapM_ (\message -> assert (invalidMessage (plan message True))) invalid
            assert $ case plan "" True of Right result -> plannedMessage result == ""; _ -> False
            assert $ case plan "" False of Left (CommitError EmptyMessage _) -> True; _ -> False
        _ -> assert False
  where
    invalidMessage (Left (CommitError InvalidCommitMessage _)) = True
    invalidMessage _ = False

commitBoundaryTests :: IO ()
commitBoundaryTests = do
    mapM_
        (assert . (== Right ()) . validateChangeBoundary)
        [ []
        , [".gaw/config"]
        , [".gaw/a", ".gaw/b"]
        , [".gaw"]
        , ["memory/current.md"]
        , ["archive/a", "skills/b"]
        , [".gaw-other/file", "memory/.gaw/config"]
        ]
    mapM_
        (assert . mixed . validateChangeBoundary)
        [ [".gaw/config", "memory/current.md"]
        , ["memory/renamed", ".gaw/original"]
        , [".gaw", ".gaw-other/file"]
        , [".gaw/config", "memory/line\nbreak"]
        , [".gaw/config", BS.concat ["memory/", BS.pack [255]]]
        ]
    let raw = BS.concat [".gaw/config\0memory/line\nbreak\0memory/", BS.pack [255], "\0"]
    assert $ case parseChangedPaths raw of
        Right paths -> length paths == 3 && mixed (validateChangeBoundary paths)
        _ -> False
    assert $ parseChangedPaths "" == Right []
    assert $ parseChangedPaths (BS.init raw) == Left UnterminatedRecord
    assert $ case parseChangedPaths "a\0\0" of
        Left (MalformedRecord _) -> True
        _ -> False
    assert $ case validateChangeBoundary [".gaw/config", "memory/a"] of
        Left problem -> ":MIXED-PROTOCOL-CHANGES" `BS.isInfixOf` renderCommitError problem
        _ -> False
  where
    mixed (Left (CommitError MixedProtocolChanges _)) = True
    mixed _ = False

invalidSchema :: Either ConfigError a -> Bool
invalidSchema (Left (InvalidSchema _)) = True
invalidSchema _ = False

isLimit :: Either ConfigError a -> Bool
isLimit (Left (LimitExceeded _)) = True
isLimit _ = False

invalidHookInput :: Either HookError [RefUpdate] -> Bool
invalidHookInput (Left (InvalidInput _)) = True
invalidHookInput _ = False

invalidRef :: Either RefNameError RefName -> Bool
invalidRef (Left (InvalidRefName _)) = True
invalidRef _ = False

assertCase :: (Either ConfigError Config -> Bool) -> BS.ByteString -> IO ()
assertCase predicate input =
    if predicate (parseConfig input)
        then pure ()
        else do
            putStrLn ("Unexpected config result for " <> show input <> ": " <> show (parseConfig input))
            exitFailure

versionedConfigTests :: IO ()
versionedConfigTests = do
    let v0 = "(:workspace ((:directory \"notes\") (:directory \"notes/archive\") (:file \"CONTEXT.md\")))"
        explicit0 = "(:version 0 :workspace ((:directory \"notes\") (:directory \"notes/archive\") (:file \"CONTEXT.md\")))"
        v1 = "(:version 1 :workspace ((:memory ((:directory \"notes\"))) (:archive ((:directory \"notes/archive\"))) (:memory ((:file \"CONTEXT.md\")))))"
        bytes = BS.replicate 40 97
        note = GitEntry "100644" "blob" bytes "notes/a" 0 False
        context = note{entryPath = "CONTEXT.md"}
        good = synthesizeIndexDirectories [note, context]
        samples = [good, [note{entryPath = "outside"}], [note{entryPath = "notes", entryMode = "160000", entryType = "commit"}], [note{entryPath = ".GAW/config"}], [note{entryStage = 2}]]
    case (parseConfig v0, parseConfig explicit0, parseConfig v1) of
        (Right legacy, Right explicit, Right grouped) -> do
            assert (legacy == explicit)
            assert (configVersion grouped == ConfigV1)
            assert (length (configSections grouped) == 3)
            assert (configWorkspace legacy == configWorkspace grouped)
            assert (null (configWarnings grouped))
            mapM_
                ( \entries -> do
                    assert (validateWorkspace (effectiveWorkspace legacy) entries == validateWorkspace (effectiveWorkspace grouped) entries)
                    assert (firstProjectPathConflict (effectiveWorkspace legacy) entries == firstProjectPathConflict (effectiveWorkspace grouped) entries)
                )
                samples
        other -> print other >> exitFailure
    let mixed = "(:version 1 :workspace ((:directory \"misc\") (:research ((:directory \"experiments\"))) (:research ())))"
    case parseConfig mixed of
        Right config -> do
            assert (length (configWorkspace config) == 2 && null (configWarnings config))
            assert $ case configSections config of
                [DirectEntry _, RoleGroup "research" [_], RoleGroup "research" []] -> True
                _ -> False
        other -> print other >> exitFailure
    assert (parseConfig "(:version 2 :workspace :future-shape)" == Left (UnsupportedVersion 2))
    assert (parseConfig "(:version 2 :workspace #(:future))" == Left (UnsupportedVersion 2))
    assert (parseConfig "(:version v2 :workspace #(:future))" == Left (UnrecognizedVersion "v2"))
    assert (parseConfig "(:workspace () :version 2)" == Left (UnsupportedVersion 2))
    assert $ case parseConfig "(:workspace () :version 1)" of
        Right config -> configVersion config == ConfigV1
        _ -> False
    assert (invalidSyntax (parseConfig "(:workspace #(:future) :version 2)"))
    assert (recognizeConfigVersion "(:workspace () :version 1)" == Right LegacyConfig)
    assert (recognizeConfigVersion " ; comment\n (:version ; comment\n 2 :workspace #(:future))" == Right (NumericVersion 2))
    assert (recognizeConfigVersion "(:version v2 :workspace #(:future))" == Right (OpaqueVersion "v2"))
    assert (recognizeConfigVersion "(:version 2.0 :workspace #(:future))" == Right (OpaqueVersion "2.0"))
    assert (recognizeConfigVersion "(:version #x2 :workspace #(:future))" == Right (OpaqueVersion "#x2"))
    assert (recognizeConfigVersion "(:version 20abc :workspace ())" == Right (OpaqueVersion "20abc"))
    assert (unrecognizedVersionDetail "v2\ESC[31m" == "Unrecognized config version v2\\x1B[31m")
    assert (BS.length (unrecognizedVersionDetail (BS.replicate 100 97)) < 100)
    assert (recognizeConfigVersion "(:version -1 :workspace ())" == Left (InvalidSchema "Config version must be a non-negative integer"))
    assert (recognizeConfigVersion "(:version :future :workspace ())" == Left (InvalidSchema "Config version must be a non-negative integer"))
    assert (recognizeConfigVersion "(:version)" == Left (InvalidSchema "Config version must be a non-negative integer"))
    assert (recognizeConfigVersion "(:version (:future))" == Left (InvalidSchema "Config version must be a non-negative integer"))
    assert (invalidSyntax (parseConfig "(:version 1 :workspace #(:future))"))
    mapM_
        (assert . isLimit . recognizeConfigVersion)
        [BS.replicate 65537 32, "(:version 2 " <> BS.replicate 16 40 <> BS.replicate 16 41 <> ")"]
    mapM_
        (assert . invalidSyntax . recognizeConfigVersion)
        [ "(:version 2 :workspace #(:future)"
        , "(:version 2 :workspace #(:future)) (:workspace ())"
        , "(:version 2 :workspace (\"bad\\n\"))"
        , BS.pack [0xef, 0xbb, 0xbf, 40, 41]
        , BS.pack [0xff]
        ]
    mapM_
        (assertCase invalidSchema)
        [ "(:version -1 :workspace ())"
        , "(:version \"1\" :workspace ())"
        , "(:version 1 :version 1 :workspace ())"
        , "(:version 1 :workspace () :workspace ())"
        , "(:version 1 :workspace)"
        , "(:version 1)"
        , "(:version 0 :workspace () :description \"extra\")"
        , "(:workspace ((:memory ((:file \"a\")))))"
        , "(:version 1 :workspace ((:Memory ((:file \"a\")))))"
        , "(:version 1 :workspace ((:bad_role ())))"
        , "(:version 1 :workspace ((:file ((:file \"a\")))))"
        , "(:version 1 :workspace ((:directory ((:file \"a\")))))"
        , "(:version 1 :workspace ((:memory ((:unknown \"a\")))))"
        , "(:version 1 :workspace ((:memory ((:archive ((:file \"a\")))))))"
        , "(:version 1 :workspace ((:memory ((:file \"a\"))) (:archive ((:directory \"a\")))))"
        , "(:version 1 :workspace ((:file \"a\") (:memory ((:file \"a\")))))"
        , "(:version 1 :workspace () :description 0 :description 1)"
        ]
    case parseConfig "(:version 1 :workspace () :description (\"extra\" :custom 12) :future ())" of
        Right config -> assert (configWarnings config == [UnknownTopLevelField "description", UnknownTopLevelField "future"])
        other -> print other >> exitFailure
    assert $ isLimit (parseConfig ("(:version 1 :workspace ((:memory (" <> BS.concat ["(:file \"p" <> TE.encodeUtf8 (DataText.pack (show i)) <> "\")" | i <- [1 .. 1025 :: Int]] <> "))))"))
    assert $ isLimit (parseConfig (BS.replicate 17 40 <> BS.replicate 17 41))

layoutTests :: IO ()
layoutTests = do
    let uuid = "01234567-89ab-4cde-8fab-0123456789ab"
        layout = Auxiliary uuid
        branch = "refs/heads/_gaw_aux_" <> uuid
        file path = GitEntry "100644" "blob" (BS.replicate 40 97) path 0 False
    requireRef <- either (const exitFailure) pure (parseSourceRef branch)
    assert (auxiliaryUuid requireRef == Just uuid)
    mapM_
        ( \name -> case parseSourceRef ("refs/heads/_gaw_aux_" <> name) of
            Right ref -> assert (auxiliaryUuid ref == Nothing && auxiliaryReserved ref)
            Left _ -> exitFailure
        )
        [ "01234567-89ab-1cde-8fab-0123456789ab"
        , "01234567-89AB-4cde-8fab-0123456789ab"
        , "01234567-89ab-4cde-cfab-0123456789ab"
        , "bad"
        ]
    config <- either (const exitFailure) pure (parseConfig "(:workspace ((:directory \"memory\")))")
    let workspace = effectiveWorkspace config
        entries = synthesizeIndexDirectories [file (configPath layout), file (uuid <> "/memory/note")]
    assert (validateWorkspaceAt layout workspace entries == Right ())
    assert (validateWorkspaceAt layout workspace (entries ++ [file "outside"]) == Left (OutsideDeclaredWorkspace "outside"))
    assert (validateWorkspaceAt layout workspace (entries ++ [file (uuid <> "/other")]) == Left (OutsideDeclaredWorkspace "other"))
    assert (validateWorkspaceAt layout workspace (entries ++ [(file "outside"){entryStage = 2}]) /= Right ())
    assert (firstProjectPathConflictAt layout workspace [file ".gaw/config", file "memory/a"] == Nothing)
    assert (firstProjectPathConflictAt layout workspace [file (uuid <> "/memory/a")] == Just (uuid <> "/memory/a"))
    assert (firstProjectPathConflictAt layout workspace [file uuid] == Just uuid)
