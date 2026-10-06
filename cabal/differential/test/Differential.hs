{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (evaluate, finally)
import Control.Monad (forM_, void)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.Maybe (fromMaybe)
import System.Directory (createDirectory, getTemporaryDirectory, removeDirectoryRecursive)
import System.Environment (getEnvironment, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>), takeDirectory, takeFileName)
import System.IO (hClose)
import qualified System.Posix.Temp.ByteString as Temp
import System.Process (CreateProcess (..), StdStream (CreatePipe), proc, withCreateProcess, waitForProcess)

data ProcessResult = ProcessResult ExitCode BS.ByteString BS.ByteString
  deriving (Eq, Show)

main :: IO ()
main = do
  oracle <- required "GAW_ORACLE_EXECUTABLE"
  haskell <- required "GAW_HASKELL_EXECUTABLE"
  let cases =
        [ []
        , ["unknown"]
        , ["--version"]
        , ["version"]
        , ["--help"]
        , ["-h"]
        , ["help"]
        ] ++ [["help", topic] | topic <-
          ["overview", "commit", "show", "check", "status", "deploy", "undeploy",
           "init", "branch", "hooks", "recovery"]]
  forM_ cases $ \args -> do
    reference <- run oracle args
    candidate <- run haskell args
    if reference == candidate
      then pure ()
      else do
        putStrLn ("Differential mismatch for " ++ show args)
        putStrLn ("oracle: " ++ show reference)
        putStrLn ("haskell: " ++ show candidate)
        exitFailure
  git <- maybe "git" id <$> lookupEnv "GIT"
  tempRoot <- getTemporaryDirectory
  fixtureRoot <- BSC.unpack <$> Temp.mkdtemp (BSC.pack (tempRoot </> "gaw-differential-"))
  compareShow git oracle haskell fixtureRoot `finally` removeDirectoryRecursive fixtureRoot
  compareHook git oracle haskell
  lifecycleRoot <- BSC.unpack <$> Temp.mkdtemp
    (BSC.pack (tempRoot </> "gaw-undeploy-differential-"))
  compareUndeploy git oracle haskell lifecycleRoot
    `finally` removeDirectoryRecursive lifecycleRoot
  deployRoot <- BSC.unpack <$> Temp.mkdtemp
    (BSC.pack (tempRoot </> "gaw-deploy-differential-"))
  compareDeploy git oracle haskell deployRoot
    `finally` removeDirectoryRecursive deployRoot
  branchRoot <- BSC.unpack <$> Temp.mkdtemp
    (BSC.pack (tempRoot </> "gaw-branch-differential-"))
  compareBranch git oracle haskell branchRoot
    `finally` removeDirectoryRecursive branchRoot
  initRoot <- BSC.unpack <$> Temp.mkdtemp
    (BSC.pack (tempRoot </> "gaw-init-differential-"))
  compareInit git oracle haskell initRoot
    `finally` removeDirectoryRecursive initRoot
  bareRoot <- BSC.unpack <$> Temp.mkdtemp
    (BSC.pack (tempRoot </> "gaw-bare-differential-"))
  compareBareStatus git oracle haskell bareRoot
    `finally` removeDirectoryRecursive bareRoot
  putStrLn "CLI help/version/show/check/status/commit/deploy/undeploy/branch/init and hook differential passed"

compareBareStatus :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareBareStatus git oracle haskell root =
  forM_ ["files", "reftable"] $ \backend -> do
    let oldRepo = root </> (backend ++ "-oracle")
        newRepo = root </> (backend ++ "-haskell")
    forM_ [oldRepo, newRepo] $ \repository ->
      expectGit git ["init", "--bare", "--quiet", "--ref-format=" ++ backend,
        repository] root []
    compareOne oldRepo newRepo Nothing Nothing
    oldInit <- runIn (Just oldRepo) [] oracle ["init", "--branch", "gaw"]
    newInit <- runIn (Just newRepo) [] haskell ["init", "--branch", "gaw"]
    oldOid <- initialOutputOid oldInit
    newOid <- initialOutputOid newInit
    compareOne oldRepo newRepo (Just oldOid) (Just newOid)
  where
    compareOne oldRepo newRepo oldOid newOid = do
      old <- runIn (Just oldRepo) [] oracle ["status"]
      new <- runIn (Just newRepo) [] haskell ["status"]
      let scrub root oid result = normalizeRoot root $ case oid of
            Nothing -> result
            Just value -> replaceResult value "<initial>" result
          normalizedOld = scrub oldRepo oldOid old
          normalizedNew = scrub newRepo newOid new
      if normalizedOld == normalizedNew then pure () else do
        putStrLn "Bare/reftable status mismatch"
        putStrLn ("oracle: " ++ show normalizedOld)
        putStrLn ("haskell: " ++ show normalizedNew)
        exitFailure

compareInit :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareInit git oracle haskell root =
  forM_ [False, True] $ \withWorktree -> do
    let variant = if withWorktree then "worktree" else "repository-only"
        oldRoot = root </> (variant ++ "-old")
        newRoot = root </> (variant ++ "-new")
        oldRepo = oldRoot </> "repository"
        newRepo = newRoot </> "repository"
        oldAgent = oldRoot </> "agent"
        newAgent = newRoot </> "agent"
        oldArgs = ["init", "--branch", "gaw"] ++
          if withWorktree then ["--worktree-path", oldAgent] else []
        newArgs = ["init", "--branch", "gaw"] ++
          if withWorktree then ["--worktree-path", newAgent] else []
    createDirectory oldRoot
    createDirectory newRoot
    setupRepo git oldRepo
    setupRepo git newRepo
    forM_ [["init"], ["init", "--branch"], ["init", "--branch", "main"],
      ["init", "--branch", "gaw", "--worktree-path", oldRepo]] $ \args -> do
        let candidateArgs = map (\arg -> if arg == oldRepo then newRepo else arg) args
        old <- runIn (Just oldRepo) [] oracle args
        new <- runIn (Just newRepo) [] haskell candidateArgs
        if normalizeRoot oldRoot old == normalizeRoot newRoot new
          then pure () else do
            putStrLn ("Init preflight mismatch for " ++ show args)
            putStrLn ("oracle: " ++ show (normalizeRoot oldRoot old))
            putStrLn ("haskell: " ++ show (normalizeRoot newRoot new))
            exitFailure
    old <- runIn (Just oldRepo) [] oracle oldArgs
    new <- runIn (Just newRepo) [] haskell newArgs
    oldOid <- initialOutputOid old
    newOid <- initialOutputOid new
    let normalizedOld = normalizeRoot oldRoot (replaceResult oldOid "<initial>" old)
        normalizedNew = normalizeRoot newRoot (replaceResult newOid "<initial>" new)
    if normalizedOld == normalizedNew then pure () else do
      putStrLn "Init CLI mismatch"
      putStrLn ("oracle: " ++ show normalizedOld)
      putStrLn ("haskell: " ++ show normalizedNew)
      exitFailure
    oldCommit <- commitObject git oldRepo oldOid
    newCommit <- commitObject git newRepo newOid
    compareInitialObjects oldCommit newCommit
    oldSnapshot <- initSnapshot git oldRepo oldRoot oldOid
    newSnapshot <- initSnapshot git newRepo newRoot newOid
    if oldSnapshot == newSnapshot then pure () else do
      putStrLn "Init repository snapshot mismatch"
      putStrLn ("oracle: " ++ show oldSnapshot)
      putStrLn ("haskell: " ++ show newSnapshot)
      exitFailure
    oldAgain <- runIn (Just oldRepo) [] oracle oldArgs
    newAgain <- runIn (Just newRepo) [] haskell newArgs
    if normalizeRoot oldRoot oldAgain == normalizeRoot newRoot newAgain
      then pure () else do
        putStrLn "Init repeated-run mismatch"
        exitFailure

initialOutputOid :: ProcessResult -> IO BS.ByteString
initialOutputOid result = case result of
  ProcessResult ExitSuccess output "" ->
    let prefix = "Initialized GAW branch gaw at "
        suffix = " ("
    in case BS.stripPrefix prefix output of
      Just remaining ->
        let (oid, rest) = BS.breakSubstring suffix remaining
        in if BS.length oid `elem` [40, 64] && not (BS.null rest)
          then pure oid else putStrLn ("Malformed init output: " ++ show result) >> exitFailure
      Nothing -> putStrLn ("Malformed init output: " ++ show result) >> exitFailure
  _ -> putStrLn ("Init command failed: " ++ show result) >> exitFailure

compareInitialObjects :: BS.ByteString -> BS.ByteString -> IO ()
compareInitialObjects oldObject newObject =
  case (parse oldObject, parse newObject) of
    (Just (oldTree, oldParents, oldAuthor, oldCommitter, oldExtras, oldMessage),
     Just (newTree, newParents, newAuthor, newCommitter, newExtras, newMessage))
      | oldTree == newTree && null oldParents && oldParents == newParents
        && oldExtras == newExtras
        && oldMessage == newMessage && oldMessage == "Initialize GAW\n"
        && identity oldAuthor == identity newAuthor
        && identity oldCommitter == identity newCommitter
        && identity oldAuthor == "author Git Agent Workflow <gaw@invalid>"
        && identity oldCommitter == "committer Git Agent Workflow <gaw@invalid>" -> pure ()
    _ -> putStrLn "Init commit structure differs from oracle" >> exitFailure
  where
    parse bytes = case BS.breakSubstring "\n\n" bytes of
      (headers, rest) | not (BS.null rest) ->
        let fields = BS.split 10 headers
            trees = filter ("tree " `BS.isPrefixOf`) fields
            parents = filter ("parent " `BS.isPrefixOf`) fields
            authors = filter ("author " `BS.isPrefixOf`) fields
            committers = filter ("committer " `BS.isPrefixOf`) fields
            extras = filter (\field -> not (any (`BS.isPrefixOf` field)
              ["tree ", "parent ", "author ", "committer "])) fields
        in case (trees, authors, committers) of
          ([tree], [author], [committer]) ->
            Just (tree, parents, author, committer, extras, BS.drop 2 rest)
          _ -> Nothing
      _ -> Nothing
    identity = BS.intercalate " " . dropLastTwo . BS.split 32
    dropLastTwo fields = take (max 0 (length fields - 2)) fields

initSnapshot :: FilePath -> FilePath -> FilePath -> BS.ByteString
  -> IO [ProcessResult]
initSnapshot git repository root oid =
  map (normalizeRoot root . replaceResult oid "<initial>") <$> traverse
    (runIn (Just repository) [] git)
    [ ["-C", repository, "for-each-ref", "--format=%(refname)%00%(symref)%00%(objectname)",
        "refs/heads/", "refs/gaw/"]
    , ["-C", repository, "config", "--local", "--get-regexp",
        "^hook\\.gaw-reference-transaction\\."]
    , ["-C", repository, "worktree", "list", "--porcelain", "-z"]
    ]

replaceResult :: BS.ByteString -> BS.ByteString -> ProcessResult -> ProcessResult
replaceResult needle replacement (ProcessResult status output errors) =
  ProcessResult status (replaceBytes needle replacement output)
    (replaceBytes needle replacement errors)

compareBranch :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareBranch git oracle haskell root = do
  let oldRepo = root </> "oracle"
      newRepo = root </> "haskell"
  setupProtectedRepo git oldRepo
  setupProtectedRepo git newRepo
  configureProtectedRepo git oldRepo
  configureProtectedRepo git newRepo
  let compareRun args = do
        old <- runIn (Just oldRepo) [] oracle args
        new <- runIn (Just newRepo) [] haskell args
        if old == new then pure () else do
          putStrLn ("Branch CLI mismatch for " ++ show args)
          putStrLn ("oracle: " ++ show old)
          putStrLn ("haskell: " ++ show new)
          exitFailure
        oldSnapshot <- branchSnapshot git oldRepo
        newSnapshot <- branchSnapshot git newRepo
        if normalizeRoot oldRepo oldSnapshot == normalizeRoot newRepo newSnapshot
          then pure () else do
            putStrLn ("Branch repository mismatch for " ++ show args)
            exitFailure
  forM_ [["branch"], ["branch", "-m"], ["branch", "-D", "missing"],
    ["branch", "-d", "gaw"]] compareRun
  compareRun ["branch", "-m", "renamed"]
  compareRun ["branch", "-D", "renamed"]
  forM_ [oldRepo, newRepo] $ \repository ->
    expectGit git ["-C", repository, "-c",
      "hook.gaw-reference-transaction.enabled=false", "branch", "other", "HEAD"]
      repository []
  compareRun ["branch", "-d", "other"]

branchSnapshot :: FilePath -> FilePath -> IO ProcessResult
branchSnapshot git repository = runIn (Just repository) [] git
  ["-C", repository, "for-each-ref",
   "--format=%(refname)%00%(symref)%00%(objectname)", "refs/heads/", "refs/gaw/"]

compareDeploy :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareDeploy git oracle haskell root = do
  let oldRoot = root </> "old"
      newRoot = root </> "new"
      oldRepo = oldRoot </> "repository"
      newRepo = newRoot </> "repository"
      oldAgent = oldRoot </> "agent"
      newAgent = newRoot </> "agent"
  createDirectory oldRoot
  createDirectory newRoot
  setupProtectedRepo git oldRepo
  setupProtectedRepo git newRepo
  forM_ [oldRepo, newRepo] $ \repository ->
    expectGit git ["-C", repository, "symbolic-ref", "HEAD", "refs/heads/main"] repository []
  let compareRun oldArgs newArgs = do
        old <- runIn (Just oldRepo) [] oracle oldArgs
        new <- runIn (Just newRepo) [] haskell newArgs
        let normalizedOld = normalizeRoot oldRoot old
            normalizedNew = normalizeRoot newRoot new
        if normalizedOld == normalizedNew then pure () else do
          putStrLn ("Deploy CLI mismatch for " ++ show oldArgs)
          putStrLn ("oracle: " ++ show normalizedOld)
          putStrLn ("haskell: " ++ show normalizedNew)
          exitFailure
        oldSnapshot <- deploySnapshot git oldRepo oldRoot
        newSnapshot <- deploySnapshot git newRepo newRoot
        if oldSnapshot == newSnapshot then pure () else do
          putStrLn ("Deploy repository mismatch for " ++ show oldArgs)
          putStrLn ("oracle: " ++ show oldSnapshot)
          putStrLn ("haskell: " ++ show newSnapshot)
          exitFailure
  forM_ [["deploy", "--branch"], ["deploy", "--unknown"],
    ["deploy", "--branch=missing"]] $ \args -> compareRun args args
  compareRun ["deploy", "--branch=gaw"] ["deploy", "--branch=gaw"]
  compareRun ["deploy"] ["deploy"]
  compareRun ["deploy", "--branch", "gaw", "--worktree-path", oldAgent]
    ["deploy", "--branch", "gaw", "--worktree-path", newAgent]
  let failedOldRoot = root </> "failed-old"
      failedNewRoot = root </> "failed-new"
      failedOldRepo = failedOldRoot </> "repository"
      failedNewRepo = failedNewRoot </> "repository"
      failedOldAgent = failedOldRoot </> "agent"
      failedNewAgent = failedNewRoot </> "agent"
  createDirectory failedOldRoot
  createDirectory failedNewRoot
  forM_ [failedOldRepo, failedNewRepo] $ \repository -> do
    setupProtectedRepo git repository
    expectGit git ["-C", repository, "symbolic-ref", "HEAD", "refs/heads/main"] repository []
    expectGit git ["-C", repository, "config", "--local",
      "hook.gaw-test-break-check.event", "post-checkout"] repository []
    expectGit git ["-C", repository, "config", "--local",
      "hook.gaw-test-break-check.command",
      "sh -c 'git rev-parse HEAD > \"$(git rev-parse --git-path MERGE_HEAD)\"'"]
      repository []
  oldFailed <- runIn (Just failedOldRepo) [] oracle
    ["deploy", "--branch", "gaw", "--worktree-path", failedOldAgent]
  newFailed <- runIn (Just failedNewRepo) [] haskell
    ["deploy", "--branch", "gaw", "--worktree-path", failedNewAgent]
  let normalizedOldFailure = normalizeRoot failedOldRoot oldFailed
      normalizedNewFailure = normalizeRoot failedNewRoot newFailed
  if normalizedOldFailure == normalizedNewFailure then pure () else do
    putStrLn "Deploy worktree-check rollback CLI mismatch"
    putStrLn ("oracle: " ++ show normalizedOldFailure)
    putStrLn ("haskell: " ++ show normalizedNewFailure)
    exitFailure
  oldAfterFailure <- deploySnapshot git failedOldRepo failedOldRoot
  newAfterFailure <- deploySnapshot git failedNewRepo failedNewRoot
  if oldAfterFailure == newAfterFailure then pure () else do
    putStrLn "Deploy worktree-check rollback repository mismatch"
    putStrLn ("oracle: " ++ show oldAfterFailure)
    putStrLn ("haskell: " ++ show newAfterFailure)
    exitFailure
  compareRun ["deploy", "--branch", "gaw", "--worktree-path", oldAgent]
    ["deploy", "--branch", "gaw", "--worktree-path", newAgent]

deploySnapshot :: FilePath -> FilePath -> FilePath -> IO [ProcessResult]
deploySnapshot git repository root = map (normalizeRoot root) <$> traverse
  (runIn (Just repository) [] git)
  [ ["-C", repository, "for-each-ref", "--format=%(refname)%00%(symref)%00%(objectname)",
      "refs/heads/", "refs/gaw/"]
  , ["-C", repository, "config", "--local", "--get-regexp",
      "^hook\\.gaw-reference-transaction\\."]
  , ["-C", repository, "symbolic-ref", "HEAD"]
  , ["-C", repository, "worktree", "list", "--porcelain", "-z"]
  ]

compareUndeploy :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareUndeploy git oracle haskell root =
  forM_ ["healthy", "legacy", "unsafe", "direct"] $ \variant -> do
    let oldRepo = root </> (variant ++ "-oracle")
        newRepo = root </> (variant ++ "-haskell")
    setupProtectedRepo git oldRepo
    setupProtectedRepo git newRepo
    configureProtectedRepo git oldRepo
    configureProtectedRepo git newRepo
    configureUndeployVariant git oldRepo variant
    configureUndeployVariant git newRepo variant
    forM_ [["undeploy", "unexpected"], ["undeploy"]] $ \args -> do
      old <- runIn (Just oldRepo) [] oracle args
      new <- runIn (Just newRepo) [] haskell args
      if old == new then pure () else do
        putStrLn ("Undeploy CLI mismatch for " ++ variant ++ " " ++ show args)
        putStrLn ("oracle: " ++ show old)
        putStrLn ("haskell: " ++ show new)
        exitFailure
      oldSnapshot <- undeploySnapshot git oldRepo
      newSnapshot <- undeploySnapshot git newRepo
      if oldSnapshot == newSnapshot then pure () else do
        putStrLn ("Undeploy repository mismatch for " ++ variant)
        putStrLn ("oracle: " ++ show oldSnapshot)
        putStrLn ("haskell: " ++ show newSnapshot)
        exitFailure
    oldAgain <- runIn (Just oldRepo) [] oracle ["undeploy"]
    newAgain <- runIn (Just newRepo) [] haskell ["undeploy"]
    if oldAgain == newAgain then pure () else do
      putStrLn ("Undeploy idempotence mismatch for " ++ variant)
      exitFailure

configureUndeployVariant :: FilePath -> FilePath -> String -> IO ()
configureUndeployVariant git repository variant = do
  let disabled = ["-C", repository, "-c",
        "hook.gaw-reference-transaction.enabled=false"]
  case variant of
    "legacy" -> expectGit git (disabled ++ ["symbolic-ref",
      "refs/gaw/heads/gaw", "refs/heads/gaw"]) repository []
    "unsafe" -> expectGit git (disabled ++ ["symbolic-ref",
      "refs/gaw/heads/gaw", "refs/heads/other"]) repository []
    "direct" -> do
      oid <- currentOid git repository
      expectGit git (disabled ++ ["update-ref", "--no-deref",
        "refs/gaw/HEAD", BSC.unpack oid]) repository []
      expectGit git (disabled ++ ["update-ref",
        "refs/gaw/heads/gaw", BSC.unpack oid]) repository []
    _ -> pure ()

undeploySnapshot :: FilePath -> FilePath -> IO [ProcessResult]
undeploySnapshot git repository = traverse (runIn (Just repository) [] git)
  [ ["-C", repository, "for-each-ref", "--format=%(refname)%00%(symref)%00%(objectname)",
      "refs/heads/", "refs/gaw/"]
  , ["-C", repository, "config", "--local", "--get-regexp",
      "^hook\\.gaw-reference-transaction\\."]
  , ["-C", repository, "symbolic-ref", "HEAD"]
  ]

compareHook :: FilePath -> FilePath -> FilePath -> IO ()
compareHook git oracle haskell = do
  let oid = BSC.replicate 40 '0'
      protected = BS.concat [oid, " ", oid, " refs/gaw/HEAD\n"]
      cases =
        [ (["--reference-transaction", "prepared"], protected)
        , (["--reference-transaction", "committed"], protected)
        , (["--reference-transaction", "aborted"], protected)
        , (["--reference-transaction", "preparing"], protected)
        , (["--reference-transaction", "preparing"], BS.empty)
        , (["--reference-transaction"], BS.empty)
        , (["--reference-transaction", "unexpected"], BS.empty)
        ]
  forM_ cases $ \(args, input) -> do
    reference <- runInWithInput Nothing [] input oracle args
    candidate <- runInWithInput Nothing [] input haskell args
    if reference == candidate
      then pure ()
      else do
        putStrLn ("Hook mismatch for " ++ show args)
        putStrLn ("oracle: " ++ show reference)
        putStrLn ("haskell: " ++ show candidate)
        exitFailure
  tempRoot <- getTemporaryDirectory
  fixtureRoot <- BSC.unpack <$> Temp.mkdtemp (BSC.pack (tempRoot </> "gaw-hook-differential-"))
  compareSourceHook git oracle haskell fixtureRoot `finally` removeDirectoryRecursive fixtureRoot

compareSourceHook :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareSourceHook git oracle haskell root = do
  let oracleRepo = root </> "oracle"
      haskellRepo = root </> "haskell"
  setupProtectedRepo git oracleRepo
  setupProtectedRepo git haskellRepo
  compareCheck oracle haskell oracleRepo haskellRepo
  compareStatus oracle haskell oracleRepo haskellRepo
  configureProtectedRepo git oracleRepo
  configureProtectedRepo git haskellRepo
  compareCheck oracle haskell oracleRepo haskellRepo
  compareStatus oracle haskell oracleRepo haskellRepo
  compareNativeHook git oracle haskell oracleRepo haskellRepo
  createDirectory (oracleRepo </> "nested")
  createDirectory (haskellRepo </> "nested")
  compareCheckAt oracle haskell oracleRepo haskellRepo
    (oracleRepo </> "nested") (haskellRepo </> "nested")
  oracleOid <- currentOid git oracleRepo
  haskellOid <- currentOid git haskellRepo
  let zero = BSC.replicate 40 '0'
      input oid next = BS.concat [oid, " ", next, " refs/heads/gaw\n"]
      cases = [(input oracleOid zero, input haskellOid zero),
               (input oracleOid oracleOid, input haskellOid haskellOid)]
  forM_ cases $ \(oldInput, newInput) -> do
    reference <- runInWithInput (Just oracleRepo) [] oldInput oracle
      ["--reference-transaction", "preparing"]
    candidate <- runInWithInput (Just haskellRepo) [] newInput haskell
      ["--reference-transaction", "preparing"]
    if reference == candidate
      then pure ()
      else do
        putStrLn "Protected source hook mismatch"
        putStrLn ("oracle: " ++ show reference)
        putStrLn ("haskell: " ++ show candidate)
        exitFailure
  configureUnexpectedRefs git oracleRepo
  configureUnexpectedRefs git haskellRepo
  compareStatus oracle haskell oracleRepo haskellRepo
  configureDirectSelector git oracleRepo oracleOid
  configureDirectSelector git haskellRepo haskellOid
  compareStatus oracle haskell oracleRepo haskellRepo
  compareCommit git oracle haskell oracleRepo haskellRepo

compareNativeHook :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareNativeHook git oracle haskell oldRepo newRepo = do
  inheritedPath <- fromMaybe "" <$> lookupEnv "PATH"
  let invoke candidate repository args = runIn (Just repository)
        [("PATH", takeDirectory candidate ++ ":" ++ inheritedPath)]
        git (["-C", repository] ++ args)
      cases =
        [ ["update-ref", "-d", "refs/heads/gaw"]
        , ["update-ref", "--no-deref", "-d", "refs/gaw/HEAD"]
        ]
  forM_ cases $ \args -> do
    old <- invoke oracle oldRepo args
    new <- invoke haskell newRepo args
    if old == new then pure () else do
      putStrLn ("Native Git hook mismatch for " ++ show args)
      putStrLn ("oracle: " ++ show old)
      putStrLn ("haskell: " ++ show new)
      exitFailure
    oldSnapshot <- branchSnapshot git oldRepo
    newSnapshot <- branchSnapshot git newRepo
    if oldSnapshot == newSnapshot then pure () else do
      putStrLn "Native Git hook left different ref state"
      exitFailure

setupProtectedRepo :: FilePath -> FilePath -> IO ()
setupProtectedRepo git repository = do
  setupRepo git repository
  expectGit git ["-C", repository, "branch", "gaw", "HEAD"] repository []
  expectGit git ["-C", repository, "symbolic-ref", "HEAD", "refs/heads/gaw"] repository []
  let configPath = repository </> ".gaw" </> "config"
  createDirectory (repository </> ".gaw")
  BS.writeFile configPath "(:workspace ((:file \"note.txt\")))"
  expectGit git ["-C", repository, "add", "--", ".gaw/config"] repository []
  expectGit git ["-C", repository, "-c", "user.name=GAW Test", "-c",
                 "user.email=gaw-test@example.invalid", "commit", "-qm", "gaw"]
    repository [("GIT_AUTHOR_DATE", "@1700000001 +0000"),
                ("GIT_COMMITTER_DATE", "@1700000001 +0000")]

configureProtectedRepo :: FilePath -> FilePath -> IO ()
configureProtectedRepo git repository = do
  expectGit git ["-C", repository, "symbolic-ref", "refs/gaw/HEAD", "refs/heads/gaw"] repository []
  forM_ [("hook.gaw-reference-transaction.command", "git-gaw --reference-transaction"),
         ("hook.gaw-reference-transaction.event", "reference-transaction"),
         ("hook.gaw-reference-transaction.enabled", "true")] $ \(key, value) ->
    expectGit git ["-C", repository, "config", "--local", key, value] repository []

configureUnexpectedRefs :: FilePath -> FilePath -> IO ()
configureUnexpectedRefs git repository = do
  let disabled = ["-c", "hook.gaw-reference-transaction.enabled=false"]
  expectGit git (["-C", repository] ++ disabled ++
    ["symbolic-ref", "refs/gaw/HEAD", "refs/heads/missing"]) repository []
  expectGit git (["-C", repository] ++ disabled ++
    ["symbolic-ref", "refs/gaw/extra", "refs/heads/gaw"]) repository []

configureDirectSelector :: FilePath -> FilePath -> BS.ByteString -> IO ()
configureDirectSelector git repository oid = do
  expectGit git ["-C", repository, "-c", "hook.gaw-reference-transaction.enabled=false",
    "update-ref", "--no-deref", "refs/gaw/HEAD", BSC.unpack oid] repository []

currentOid :: FilePath -> FilePath -> IO BS.ByteString
currentOid git repository = do
  result <- runIn (Just repository) [] git ["-C", repository, "rev-parse", "HEAD"]
  case result of
    ProcessResult ExitSuccess bytes _ -> pure (BS.takeWhile (/= 10) bytes)
    _ -> putStrLn ("Cannot inspect hook fixture: " ++ show result) >> exitFailure

compareCommit :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareCommit git oracle haskell oracleRepo haskellRepo = do
  forM_ [["commit"], ["commit", "-m"], ["commit", "-F"],
         ["commit", "-F", "missing-message.txt"],
         ["commit", "--unknown"], ["commit", "-m", "empty"],
         ["commit", "-m", "duplicate", "refs/heads/gaw"],
         ["commit", "-m", "conflict", "refs/heads/main"]] $ \args -> do
    reference <- runIn (Just oracleRepo) [] oracle args
    candidate <- runIn (Just haskellRepo) [] haskell args
    if normalizeRoot oracleRepo reference == normalizeRoot haskellRepo candidate
      then pure () else do
      putStrLn ("Commit failure mismatch for " ++ show args)
      putStrLn ("oracle: " ++ show (normalizeRoot oracleRepo reference))
      putStrLn ("haskell: " ++ show (normalizeRoot haskellRepo candidate))
      exitFailure
  forM_ [oracleRepo, haskellRepo] $ \repository -> do
    BS.writeFile (repository </> "note.txt") "staged\n"
    expectGit git ["-C", repository, "add", "--", "note.txt"] repository []
    BS.writeFile (repository </> "note.txt") "unstaged\n"
  (oldFirst, newFirst) <- compareCommitMutation git oracle haskell
    oracleRepo haskellRepo ["commit", "-m", "checkpoint"] []
  oldProject <- fixtureProjectCommit git oracleRepo
  newProject <- fixtureProjectCommit git haskellRepo
  if oldProject /= newProject
    then putStrLn "Deterministic project fixture OIDs differ" >> exitFailure
    else pure ()
  (oldSecond, newSecond) <- compareCommitMutation git oracle haskell
    oracleRepo haskellRepo ["commit", "-m", "associated", BSC.unpack oldProject]
    [(oldFirst, newFirst)]
  forM_ [oracleRepo, haskellRepo] $ \repository ->
    BS.writeFile (repository </> "message.bin") (BS.pack [65, 1, 10])
  _ <- compareCommitMutation git oracle haskell oracleRepo haskellRepo
    ["commit", "-F", "message.bin", "--allow-empty"]
    [(oldSecond, newSecond)]
  pure ()

fixtureProjectCommit :: FilePath -> FilePath -> IO BS.ByteString
fixtureProjectCommit git repository = do
  tree <- gitResultBytes git repository ["-C", repository, "mktree"] BS.empty
  let treeOid = BS.takeWhile (/= 10) tree
  commit <- gitResultBytes git repository ["-C", repository, "commit-tree",
    BSC.unpack treeOid, "-m", "project"] BS.empty
  pure (BS.takeWhile (/= 10) commit)

gitResultBytes :: FilePath -> FilePath -> [String] -> BS.ByteString -> IO BS.ByteString
gitResultBytes git repository args input = do
  result <- runInWithInput (Just repository)
    [("GIT_AUTHOR_NAME", "GAW Test"), ("GIT_AUTHOR_EMAIL", "gaw-test@example.invalid"),
     ("GIT_COMMITTER_NAME", "GAW Test"), ("GIT_COMMITTER_EMAIL", "gaw-test@example.invalid"),
     ("GIT_AUTHOR_DATE", "@1700000002 +0000"),
     ("GIT_COMMITTER_DATE", "@1700000002 +0000")] input git args
  case result of
    ProcessResult ExitSuccess output _ -> pure output
    _ -> putStrLn ("Fixture Git command failed: " ++ show result) >> exitFailure

compareCommitMutation :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath
  -> [String] -> [(BS.ByteString, BS.ByteString)]
  -> IO (BS.ByteString, BS.ByteString)
compareCommitMutation git oracle haskell oracleRepo haskellRepo args parentMapping = do
  reference <- runIn (Just oracleRepo) [] oracle args
  candidate <- runIn (Just haskellRepo) [] haskell args
  case (reference, candidate) of
    (ProcessResult ExitSuccess oldOutput oldError,
     ProcessResult ExitSuccess newOutput newError) | oldError == newError -> do
      let oldOid = BS.takeWhile (/= 10) oldOutput
          newOid = BS.takeWhile (/= 10) newOutput
      if BS.null oldOid || BS.null newOid || oldOutput /= oldOid <> "\n"
          || newOutput /= newOid <> "\n"
        then putStrLn "Malformed commit CLI object ID" >> exitFailure
        else do
          oldTip <- currentOid git oracleRepo
          newTip <- currentOid git haskellRepo
          if oldTip /= oldOid || newTip /= newOid
            then putStrLn "Commit did not update its source branch" >> exitFailure
            else do
              oldObject <- commitObject git oracleRepo oldOid
              newObject <- commitObject git haskellRepo newOid
              compareCommitObjects parentMapping oldObject newObject
              pure (oldOid, newOid)
    _ -> do
      putStrLn "Commit success mismatch"
      putStrLn ("oracle: " ++ show reference)
      putStrLn ("haskell: " ++ show candidate)
      exitFailure

commitObject :: FilePath -> FilePath -> BS.ByteString -> IO BS.ByteString
commitObject git repository oid = do
  result <- runIn (Just repository) [] git
    ["-C", repository, "cat-file", "commit", BSC.unpack oid]
  case result of
    ProcessResult ExitSuccess bytes _ -> pure bytes
    _ -> putStrLn ("Cannot read commit object: " ++ show result) >> exitFailure

compareCommitObjects :: [(BS.ByteString, BS.ByteString)]
  -> BS.ByteString -> BS.ByteString -> IO ()
compareCommitObjects parentMapping oldObject newObject = do
  let parse bytes = case BS.breakSubstring "\n\n" bytes of
        (headers, rest) | not (BS.null rest) ->
          let lines' = BS.split 10 headers
              trees = filter ("tree " `BS.isPrefixOf`) lines'
              parents = filter ("parent " `BS.isPrefixOf`) lines'
              authors = filter ("author " `BS.isPrefixOf`) lines'
              committers = filter ("committer " `BS.isPrefixOf`) lines'
              extras = filter (\field -> not (any (`BS.isPrefixOf` field)
                ["tree ", "parent ", "author ", "committer "])) lines'
          in Just (trees, parents, authors, committers, extras, BS.drop 2 rest)
        _ -> Nothing
  case (parse oldObject, parse newObject) of
    (Just (oldTrees, oldParents, [oldAuthor], [oldCommitter], oldExtras, oldMessage),
     Just (newTrees, newParents, [newAuthor], [newCommitter], newExtras, newMessage))
      | oldTrees == newTrees && map correspond oldParents == newParents
        && oldExtras == newExtras && oldMessage == newMessage
        && validIdentity oldAuthor oldCommitter
        && validIdentity newAuthor newCommitter -> pure ()
    _ -> do
      putStrLn "Commit object graph or metadata differs from the oracle"
      exitFailure
  where
    correspond parent = case BS.stripPrefix "parent " parent of
      Just oid -> case lookup oid parentMapping of
        Just equivalent -> "parent " <> equivalent
        Nothing -> parent
      Nothing -> parent
    validIdentity author committer =
      let authorFields = BS.split 32 author
          committerFields = BS.split 32 committer
          identity fields = BS.intercalate " " (take (length fields - 2) fields)
      in length authorFields >= 5 && length committerFields >= 5
        && identity authorFields == "author Git Agent Workflow <gaw@invalid>"
        && identity committerFields == "committer Git Agent Workflow <gaw@invalid>"
        && last authorFields == "+0000" && last committerFields == "+0000"
        && authorFields !! (length authorFields - 2) ==
             committerFields !! (length committerFields - 2)

compareCheck :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareCheck oracle haskell oracleRepo haskellRepo =
  compareCheckAt oracle haskell oracleRepo haskellRepo oracleRepo haskellRepo

compareCheckAt :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareCheckAt oracle haskell oracleRepo haskellRepo oracleDirectory haskellDirectory = do
  forM_ [["check"], ["check", "unexpected"]] $ \args -> do
    reference <- runIn (Just oracleDirectory) [] oracle args
    candidate <- runIn (Just haskellDirectory) [] haskell args
    let normalizedReference = normalizeRoot oracleRepo reference
        normalizedCandidate = normalizeRoot haskellRepo candidate
    if normalizedReference == normalizedCandidate
      then pure ()
      else do
        putStrLn ("Check mismatch for " ++ show args)
        putStrLn ("oracle: " ++ show normalizedReference)
        putStrLn ("haskell: " ++ show normalizedCandidate)
        exitFailure

compareStatus :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareStatus oracle haskell oracleRepo haskellRepo = do
  forM_ [["status"], ["status", "--diagnose"], ["status", "unexpected"]] $ \args -> do
    reference <- runIn (Just oracleRepo) [] oracle args
    candidate <- runIn (Just haskellRepo) [] haskell args
    let normalizedReference = normalizeRoot oracleRepo reference
        normalizedCandidate = normalizeRoot haskellRepo candidate
    if normalizedReference == normalizedCandidate
      then pure ()
      else do
        putStrLn ("Status mismatch for " ++ show args)
        putStrLn ("oracle: " ++ show normalizedReference)
        putStrLn ("haskell: " ++ show normalizedCandidate)
        exitFailure

normalizeRoot :: FilePath -> ProcessResult -> ProcessResult
normalizeRoot root (ProcessResult status output errors) =
  ProcessResult status (replaceBytes (BSC.pack root) "<fixture>" output)
    (replaceBytes (BSC.pack root) "<fixture>" errors)

replaceBytes :: BS.ByteString -> BS.ByteString -> BS.ByteString -> BS.ByteString
replaceBytes needle replacement haystack = case BS.breakSubstring needle haystack of
  (prefix, suffix) | BS.null suffix -> prefix
                   | otherwise -> prefix <> replacement <>
                       replaceBytes needle replacement (BS.drop (BS.length needle) suffix)

compareShow :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
compareShow git oracle haskell root = do
  let oracleRepo = root </> "oracle"
      haskellRepo = root </> "haskell"
  setupRepo git oracleRepo
  setupRepo git haskellRepo
  compareCheck oracle haskell oracleRepo haskellRepo
  compareStatus oracle haskell oracleRepo haskellRepo
  let cases =
        [ ["show"]
        , ["show", "--format=%s", "--stat"]
        , ["show", "--no-diff-merges", "--", "note.txt"]
        , ["show", "--cc"]
        ]
  forM_ cases $ \args -> do
    reference <- runIn (Just oracleRepo) [] oracle args
    candidate <- runIn (Just haskellRepo) [] haskell args
    if reference == candidate
      then pure ()
      else do
        putStrLn ("Show mismatch for " ++ show args)
        putStrLn ("oracle: " ++ show reference)
        putStrLn ("haskell: " ++ show candidate)
        exitFailure

setupRepo :: FilePath -> FilePath -> IO ()
setupRepo git repository = do
  createDirectory repository
  expectGit git ["init", "-q", "-b", "main", repository] repository []
  BS.writeFile (repository </> "note.txt") "hello\n"
  expectGit git ["-C", repository, "add", "--", "note.txt"] repository []
  expectGit git ["-C", repository, "-c", "user.name=GAW Test", "-c",
                 "user.email=gaw-test@example.invalid", "commit", "-qm", "initial"]
    repository [("GIT_AUTHOR_DATE", "@1700000000 +0000"),
                ("GIT_COMMITTER_DATE", "@1700000000 +0000")]

expectGit :: FilePath -> [String] -> FilePath -> [(String, String)] -> IO ()
expectGit git args directory overrides = do
  result <- runIn (Just directory) overrides git args
  case result of
    ProcessResult ExitSuccess _ _ -> pure ()
    _ -> putStrLn ("Fixture Git command failed: " ++ show args ++ " " ++ show result) >> exitFailure

required :: String -> IO FilePath
required name = do
  value <- lookupEnv name
  case value of
    Just path | not (null path) -> pure path
    _ -> putStrLn ("Missing explicit executable: " ++ name) >> exitFailure

run :: FilePath -> [String] -> IO ProcessResult
run = runIn Nothing []

runIn :: Maybe FilePath -> [(String, String)] -> FilePath -> [String] -> IO ProcessResult
runIn directory overrides = runInWithInput directory overrides BS.empty

runInWithInput :: Maybe FilePath -> [(String, String)] -> BS.ByteString
  -> FilePath -> [String] -> IO ProcessResult
runInWithInput directory overrides inputBytes executable args = do
  inherited <- getEnvironment
  let originalPath = fromMaybe "" (lookup "PATH" inherited)
      commandPath = takeFileName executable
      hookPath = if commandPath == "git-gaw"
        then [("PATH", takeDirectory executable ++ ":" ++ originalPath)]
        else []
      environment = foldl replace inherited (hookPath ++ overrides)
  withCreateProcess (proc executable args)
    { cwd = directory, env = Just environment
    , std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe }
    $ \maybeInput maybeOutput maybeError process -> case (maybeInput, maybeOutput, maybeError) of
      (Just input, Just output, Just errors) -> do
        BS.hPut input inputBytes
        hClose input
        outputVar <- newEmptyMVar
        errorVar <- newEmptyMVar
        void $ forkIO $ do
          bytes <- BS.hGetContents output
          void (evaluate (BS.length bytes))
          putMVar outputVar bytes
        void $ forkIO $ do
          bytes <- BS.hGetContents errors
          void (evaluate (BS.length bytes))
          putMVar errorVar bytes
        out <- takeMVar outputVar
        err <- takeMVar errorVar
        status <- waitForProcess process
        pure (ProcessResult status out err)
      _ -> putStrLn "Cannot create subprocess pipes" >> exitFailure

replace :: [(String, String)] -> (String, String) -> [(String, String)]
replace environment entry = entry : filter ((/= fst entry) . fst) environment
