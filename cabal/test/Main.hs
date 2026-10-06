{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.Text.Encoding as TE
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
    Right value -> validateWorkspace value (synthesizeIndexDirectories [file]) == Right ()
      && validateWorkspace value [outside] == Left (OutsideDeclaredWorkspace "outside")
      && firstProjectPathConflict value [file] == Just nonUtfPath
    Left _ -> False
  assert $ validateSnapshot [file {entryStage = 2}] == Left (UnmergedIndex nonUtfPath)
  assert $ validateSnapshot [file {entryIntentToAdd = True}] == Left (IntentToAdd nonUtfPath)
  assert $ case config of
    Right value -> validateWorkspace value [file {entryPath = ".GAW/config"}]
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
