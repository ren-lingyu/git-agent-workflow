{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.Text as DataText
import qualified Data.Text.Encoding as TE
import Gaw.Protocol.SExpr
import Gaw.Protocol.Config
import Gaw.Protocol.Deploy
import Gaw.Protocol.Hook
import Gaw.Protocol.Ref
import Gaw.Protocol.Workspace
import Gaw.Protocol.Show
import Gaw.Protocol.Status (StatusWorktree (..))
import Gaw.System.Repository
import System.Exit (exitFailure)

assert :: Bool -> IO ()
assert True = pure ()
assert False = exitFailure

main :: IO ()
main = do
  assert $ parseSExpr "(:custom ())" == Right (SList [SKeyword "custom", SList []])
  assert $ decodeConfig (SList [SKeyword "custom", SList []])
    == Left (InvalidSchema "Unknown config keyword")
  let parsed = parseConfig "(:workspace ((:file \"a\\\"b\") (:directory \"memory\")))"
  assert $ case parsed of
    Right config -> length (configWorkspace config) == 2
    Left _ -> False
  assert $ case parseConfig "(:workspace ())" of
    Right config -> null (configWorkspace config)
    Left _ -> False
  mapM_ (assertCase invalidSyntax)
    [ ""
    , "(:workspace ()) (:workspace ())"
    , "#.(error \"unsafe\")"
    , "(:workspace ((:file \"bad\\npath\")))"
    , "(:workspace ((:file \"line\nbreak\")))"
    , "(:workspace nil)"
    , BS.pack [0xef, 0xbb, 0xbf]
    , BS.pack [0xff]
    ]
  mapM_ (assertCase invalidSchema)
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
  mapM_ (assert . invalidHookInput . parseReferenceTransaction)
    ["\n", "0 1", "0 1 refs/heads/gaw extra", "not-an-oid 1 refs/heads/gaw"]
  let update = RefUpdate (ObjectValue "0000") (ObjectValue "1111") "refs/heads/gaw"
      oldMarker = MarkerObservation "100644 blob marker" ValidCommitted Nothing
  assert $ checkProtectedSource update "refs/heads/gaw" (SourceDirect "aaaa" (Just oldMarker))
    == Left (ProtectedRef "refs/heads/gaw")
  assert $ checkProtectedSource update "refs/heads/new" (SourceDirect "aaaa" Nothing) == Right ()
  assert $ protectProtocolRef (update { updateRef = "refs/gaw/HEAD" })
    == Left (ProtectedProtocolRef "refs/gaw/HEAD")
  assert $ case parseSourceRef "refs/heads/agents" of
    Right source -> isSourceRef source && refNameBytes source == "refs/heads/agents"
    Left _ -> False
  mapM_ (assert . invalidRef . parseRefName)
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
      outside = file {entryPath = "outside"}
  assert $ case config of
    Right value -> validateWorkspace (effectiveWorkspace value) (synthesizeIndexDirectories [file]) == Right ()
      && validateWorkspace (effectiveWorkspace value) [outside] == Left (OutsideDeclaredWorkspace "outside")
      && firstProjectPathConflict (effectiveWorkspace value) [file] == Just nonUtfPath
    Left _ -> False
  assert $ validateSnapshot [file {entryStage = 2}] == Left (UnmergedIndex nonUtfPath)
  assert $ validateSnapshot [file {entryIntentToAdd = True}] == Left (IntentToAdd nonUtfPath)
  assert $ case config of
    Right value -> validateWorkspace (effectiveWorkspace value) [file {entryPath = ".GAW/config"}]
      == Left (NoncanonicalProtocolPath ".GAW/config")
    Left _ -> False
  assert $ prepareShowArguments ["--no-diff-merges", "--", "-m"]
    == Right ["show", "--no-diff-merges", "--first-parent", "--", "-m"]
  assert $ prepareShowArguments ["--diff-merges=off", "--dd"]
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
  assert $ planWorktree "refs/heads/gaw" Nothing False [attached]
    == Right (ExistingWorktree "/tmp/agent")
  assert $ planWorktree "refs/heads/gaw" (Just "/tmp/agent/") False [attached]
    == Right (ExistingWorktree "/tmp/agent/")
  assert $ planWorktree "refs/heads/gaw" (Just "/tmp/other") False [other]
    == Left (PathAttachedElsewhere "/tmp/other")
  assert $ planWorktree "refs/heads/gaw" (Just "/tmp/new") False [attached]
    == Left (BranchAlreadyAttached "refs/heads/gaw" "/tmp/agent")
  assert $ planWorktree "refs/heads/gaw" (Just "/tmp/new") True []
    == Left (PathOccupied "/tmp/new")
  versionedConfigTests
  putStrLn "Protocol tests passed"

invalidSyntax :: Either ConfigError Config -> Bool
invalidSyntax (Left (InvalidSyntax _)) = True
invalidSyntax _ = False

invalidSchema :: Either ConfigError Config -> Bool
invalidSchema (Left (InvalidSchema _)) = True
invalidSchema _ = False

isLimit :: Either ConfigError Config -> Bool
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
      context = note {entryPath = "CONTEXT.md"}
      good = synthesizeIndexDirectories [note, context]
      samples = [good, [note {entryPath = "outside"}], [note {entryPath = "notes", entryMode = "160000", entryType = "commit"}], [note {entryPath = ".GAW/config"}], [note {entryStage = 2}]]
  case (parseConfig v0, parseConfig explicit0, parseConfig v1) of
    (Right legacy, Right explicit, Right grouped) -> do
      assert (legacy == explicit)
      assert (configVersion grouped == ConfigV1)
      assert (length (configSections grouped) == 3)
      assert (configWorkspace legacy == configWorkspace grouped)
      assert (null (configWarnings grouped))
      mapM_ (\entries -> do
        assert (validateWorkspace (effectiveWorkspace legacy) entries == validateWorkspace (effectiveWorkspace grouped) entries)
        assert (firstProjectPathConflict (effectiveWorkspace legacy) entries == firstProjectPathConflict (effectiveWorkspace grouped) entries)) samples
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
  mapM_ (assertCase invalidSchema)
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
  assert $ isLimit (parseConfig ("(:version 1 :workspace ((:memory (" <> BS.concat ["(:file \"p" <> TE.encodeUtf8 (DataText.pack (show i)) <> "\")" | i <- [1..1025 :: Int]] <> "))))"))
  assert $ isLimit (parseConfig (BS.replicate 17 40 <> BS.replicate 17 41))
