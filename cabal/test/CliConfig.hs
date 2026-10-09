{-# LANGUAGE OverloadedStrings #-}

module CliConfig (configCliTests) where

import Control.Exception (finally)
import Control.Monad (unless)
import qualified Data.ByteString.Char8 as BSC
import Data.List (isInfixOf, intercalate)
import Gaw.Application.State (inspectCommittedState)
import Gaw.Protocol.Ref (parseSourceRef)
import Gaw.Protocol.State
import Gaw.System.Git (Git (..), GitInvocation (..), GitResult (..), runGitPosix)
import qualified System.OsString.Posix as OS
import System.Directory (findExecutable, makeAbsolute, createDirectory,
  createDirectoryIfMissing, removePathForcibly, removeFile)
import System.Exit (ExitCode (..))
import System.FilePath ((</>), getSearchPath)
import System.Environment (getEnvironment)
import System.Process

-- The internal Cabal tool dependency supplies the candidate executable.
configCliTests :: FilePath -> FilePath -> IO ()
configCliTests temporary git = do
  found <- findExecutable "git-gaw" >>= maybe
    (fail "Cabal did not expose the candidate git-gaw") pure
  candidate <- makeAbsolute found
  let root = temporary </> "config-cli"
  createDirectory root
  finally (do
    newConfig candidate root
    boundaryChanges candidate root
    migrateLegacy candidate root
    futureVersion candidate root
    ) (removePathForcibly root)
  where
    invoke directory executable args = do
      paths <- mapM makeAbsolute =<< getSearchPath
      environment <- getEnvironment
      let absoluteEnvironment = ("PATH", intercalate ":" paths) :
            filter ((/= "PATH") . fst) environment
      readCreateProcessWithExitCode ((proc executable args)
        {cwd = Just directory, env = Just absoluteEnvironment}) ""
    success directory executable args = do
      (code, out, err) <- invoke directory executable args
      unless (code == ExitSuccess) $ fail (show args ++ " failed: " ++ out ++ err)
      pure out
    failure directory executable args = do
      (code, out, err) <- invoke directory executable args
      unless (code /= ExitSuccess) $ fail (show args ++ " unexpectedly succeeded")
      pure (out ++ err)
    gitOk directory = success directory git
    cliOk candidate directory = success directory candidate
    cliFail candidate directory = failure directory candidate
    require condition detail = unless condition (fail detail)
    config directory bytes = do
      createDirectoryIfMissing True (directory </> ".gaw")
      writeFile (directory </> ".gaw/config") bytes
      _ <- gitOk directory ["add", "--", ".gaw/config"]
      pure ()
    nativeCommit directory message = do
      _ <- gitOk directory ["-c", "commit.gpgsign=false", "commit", "-q", "-m", message]
      pure ()
    seed root name = do
      let directory = root </> name
      createDirectory directory
      _ <- gitOk directory ["init", "-q", "--object-format=sha1", "-b", "main"]
      _ <- gitOk directory ["config", "user.name", "Config Tests"]
      _ <- gitOk directory ["config", "user.email", "tests@invalid"]
      writeFile (directory </> "project.txt") "project\n"
      _ <- gitOk directory ["add", "--", "project.txt"]
      nativeCommit directory "project"
      pure directory
    newConfig candidate root = do
      directory <- seed root "new"
      let agent = root </> "agent"
      _ <- cliOk candidate directory ["init", "--branch", "agents", "--worktree-path", agent]
      initial <- readFile (agent </> ".gaw/config")
      require (initial == "(:version 1 :workspace ())\n") "init must emit explicit v1"
      config agent "(:version 1 :workspace ((:research ((:directory \"notes\")))) :description \"extra\")\n"
      staged <- cliOk candidate agent ["check"]
      require (isInfixOf "[warning] index-config:" staged &&
        not (isInfixOf "[warning] head-config:" staged)) "HEAD/index warnings were conflated"
      committed <- cliOk candidate agent ["commit", "-m", "v1 roles", "--", "main"]
      require (not (isInfixOf "Ignoring" committed)) "commit printed a config warning"
      checked <- cliOk candidate agent ["check"]
      require (isInfixOf "[warning] head-config:" checked &&
        isInfixOf "[warning] index-config:" checked) "check lost config warnings"
      status <- cliOk candidate directory ["status"]
      require (isInfixOf " valid" status &&
        isInfixOf "warning: Ignoring unknown top-level config field :description" status)
        "status lost warnings or invalidated a valid branch"
      _ <- cliOk candidate directory ["status", "--diagnose"]
      before <- gitOk agent ["rev-parse", "HEAD"]
      _ <- failure agent git ["update-ref", "refs/heads/agents", "main"]
      after <- gitOk agent ["rev-parse", "HEAD"]
      require (before == after) "native Git moved the valid v1 branch"
      createDirectory (directory </> "notes")
      writeFile (directory </> "notes/conflict") "collision\n"
      _ <- gitOk directory ["add", "--", "notes/conflict"]
      nativeCommit directory "conflicting project"
      conflict <- cliFail candidate agent ["commit", "-m", "collision", "--", "main"]
      require (isInfixOf "PATH-CONFLICT" conflict) "role path collision was accepted"
      unchanged <- gitOk agent ["rev-parse", "HEAD"]
      require (unchanged == before) "failed parent validation changed HEAD"
      writeFile (agent </> "notes") "must be a directory\n"
      _ <- gitOk agent ["add", "--", "notes"]
      _ <- cliFail candidate agent ["check"]
      _ <- cliFail candidate agent ["commit", "-m", "wrong kind"]
      _ <- gitOk agent ["restore", "--staged", "--", "notes"]
      removeFile (agent </> "notes")
      config agent "(:version 2 :workspace :future-shape)\n"
      unsupported <- cliFail candidate agent ["check"]
      require (isInfixOf "Unsupported config version 2" unsupported) "check hid unsupported version"
      unsupportedCommit <- cliFail candidate agent ["commit", "-m", "future"]
      require (isInfixOf "Unsupported config version 2" unsupportedCommit) "commit hid unsupported version"
      still <- gitOk agent ["rev-parse", "HEAD"]
      require (still == before) "rejected candidates changed HEAD"
      _ <- cliOk candidate agent ["branch", "-m", "renamed"]
      _ <- cliOk candidate agent ["branch", "-m", "agents"]
      pure ()
    stageRawPath directory path = do
      blob <- gitOk directory ["hash-object", "-w", "--stdin"]
      executable <- OS.fromBytes (BSC.pack git)
      location <- OS.fromBytes (BSC.pack directory)
      result <- runGit (runGitPosix executable) (GitInvocation location
        ["update-index", "--add", "--cacheinfo", "100644",
          BSC.pack (takeWhile (/= '\n') blob), path] Nothing [])
      require (gitExitCode result == 0) "could not stage the raw-byte fixture path"
    removeRawPath directory path = do
      executable <- OS.fromBytes (BSC.pack git)
      location <- OS.fromBytes (BSC.pack directory)
      result <- runGit (runGitPosix executable) (GitInvocation location
        ["update-index", "--force-remove", path] Nothing [])
      require (gitExitCode result == 0) "could not unstage the raw-byte fixture path"
    boundaryChanges candidate root = do
      directory <- seed root "boundary"
      let agent = root </> "boundary-agent"
          metadata = agent </> ".gaw/meta"
          note = agent </> "memory/old"
          rawPath = BSC.pack "memory/" <> BSC.singleton '\255'
          rejectMixed label = do
            before <- gitOk agent ["rev-parse", "HEAD"]
            errorText <- cliFail candidate agent ["commit", "-m", label]
            require (isInfixOf ":MIXED-PROTOCOL-CHANGES" errorText)
              ("missing mixed-change error for " ++ label)
            after <- gitOk agent ["rev-parse", "HEAD"]
            require (before == after) ("mixed change moved HEAD for " ++ label)
      _ <- cliOk candidate directory ["init", "--branch", "agents", "--worktree-path", agent]
      config agent "(:version 1 :workspace ((:memory ((:directory \"memory\")))))\n"
      _ <- cliOk candidate agent ["commit", "-m", "config only"]
      createDirectory (agent </> "memory")
      writeFile metadata "metadata\n"
      writeFile note "memory\n"
      _ <- gitOk agent ["add", "--", ".gaw/meta", "memory/old"]
      rejectMixed "mixed additions"
      _ <- gitOk agent ["restore", "--staged", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol addition"]
      _ <- gitOk agent ["add", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "workspace addition"]
      -- Existing files on both sides do not count as changed paths.
      writeFile metadata "changed metadata\n"
      writeFile note "changed memory\n"
      _ <- gitOk agent ["add", "--", ".gaw/meta", "memory/old"]
      rejectMixed "mixed content"
      _ <- gitOk agent ["restore", "--staged", "--", ".gaw/meta"]
      _ <- cliOk candidate agent ["commit", "-m", "workspace content only"]
      _ <- gitOk agent ["add", "--", ".gaw/meta"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol content only"]
      -- Only mode bits change here; filesystem chmod is unnecessary.
      _ <- gitOk agent ["update-index", "--chmod=+x", "--", ".gaw/meta", "memory/old"]
      rejectMixed "mixed modes"
      _ <- gitOk agent ["restore", "--staged", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol mode only"]
      _ <- gitOk agent ["update-index", "--chmod=+x", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "workspace mode only"]
      removeFile metadata
      removeFile note
      _ <- gitOk agent ["add", "-u", "--", ".gaw/meta", "memory/old"]
      rejectMixed "mixed deletions"
      _ <- gitOk agent ["restore", "--staged", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol deletion"]
      _ <- gitOk agent ["add", "-u", "--", "memory/old"]
      _ <- cliOk candidate agent ["commit", "-m", "workspace deletion"]
      -- Explicitly enable renames to test the query's override.
      _ <- gitOk agent ["config", "diff.renames", "true"]
      writeFile (agent </> ".gaw/source") "move me\n"
      _ <- gitOk agent ["add", "--", ".gaw/source"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol source"]
      _ <- gitOk agent ["mv", "--", ".gaw/source", "memory/moved"]
      rejectMixed "cross-boundary move"
      _ <- gitOk agent ["restore", "--staged", "--", "memory/moved"]
      _ <- cliOk candidate agent ["commit", "-m", "remove protocol source"]
      _ <- gitOk agent ["add", "--", "memory/moved"]
      _ <- cliOk candidate agent ["commit", "-m", "add workspace destination"]
      _ <- gitOk agent ["mv", "--", "memory/moved", "memory/renamed"]
      _ <- cliOk candidate agent ["commit", "-m", "workspace rename"]
      _ <- gitOk agent ["mv", "--", "memory/renamed", ".gaw/destination"]
      rejectMixed "reverse cross-boundary move"
      _ <- gitOk agent ["restore", "--staged", "--", ".gaw/destination"]
      _ <- cliOk candidate agent ["commit", "-m", "remove workspace source"]
      _ <- gitOk agent ["add", "--", ".gaw/destination"]
      _ <- cliOk candidate agent ["commit", "-m", "add protocol destination"]
      _ <- gitOk agent ["mv", "--", ".gaw/destination", ".gaw/renamed"]
      _ <- cliOk candidate agent ["commit", "-m", "protocol rename"]
      writeFile (agent </> "memory/line\nbreak") "newline path\n"
      writeFile (agent </> ".gaw/unusual") "metadata\n"
      _ <- gitOk agent ["add", "--", ".gaw/unusual", "memory/line\nbreak"]
      rejectMixed "newline path"
      _ <- gitOk agent ["restore", "--staged", "--", "memory/line\nbreak"]
      stageRawPath agent rawPath
      rejectMixed "non-UTF8 path"
      removeRawPath agent rawPath
      _ <- cliOk candidate agent ["commit", "-m", "protocol with raw paths unstaged"]
      _ <- gitOk agent ["add", "--", "memory/line\nbreak"]
      stageRawPath agent rawPath
      _ <- cliOk candidate agent ["commit", "-m", "unusual workspace paths"]
      previous <- gitOk agent ["rev-parse", "HEAD"]
      tree <- gitOk agent ["rev-parse", "HEAD^{tree}"]
      project <- gitOk directory ["rev-parse", "main"]
      _ <- cliOk candidate agent ["commit", "-m", "unchanged tree association", "--", "main"]
      sameTree <- gitOk agent ["rev-parse", "HEAD^{tree}"]
      first <- gitOk agent ["rev-parse", "HEAD^1"]
      second <- gitOk agent ["rev-parse", "HEAD^2"]
      require (tree == sameTree && first == previous && second == project)
        "unchanged-tree project association regressed"
      _ <- cliOk candidate agent ["commit", "--allow-empty", "-m", "intentional empty"]
      noChange <- cliFail candidate agent ["commit", "-m", "empty without flag"]
      require (isInfixOf ":EMPTY-COMMIT" noChange) "empty-commit behavior changed"
      _ <- cliOk candidate agent ["check"]
      pure ()
    migrateLegacy candidate root = do
      directory <- seed root "legacy"
      _ <- gitOk directory ["checkout", "-q", "-b", "agents"]
      let legacy = "(:workspace ((:directory \"memory\")))\n"
      config directory legacy
      _ <- gitOk directory ["rm", "--", "project.txt"]
      nativeCommit directory "implicit v0"
      previous <- gitOk directory ["rev-parse", "HEAD"]
      _ <- cliOk candidate directory ["deploy", "--branch", "agents"]
      config directory "(:version 1 :workspace ((:memory ((:directory \"memory\")))))\n"
      _ <- cliOk candidate directory ["commit", "-m", "adopt v1"]
      _ <- cliOk candidate directory ["check"]
      preserved <- gitOk directory ["show", takeWhile (/= '\n') previous ++ ":.gaw/config"]
      parent <- gitOk directory ["rev-parse", "HEAD^1"]
      require (preserved == legacy && parent == previous) "v1 adoption changed its v0 parent"
    futureVersion candidate root = do
      directory <- seed root "future"
      _ <- gitOk directory ["checkout", "-q", "-b", "agents"]
      config directory "(:version 2 :workspace :future-shape)\n"
      nativeCommit directory "future config"
      executable <- OS.fromBytes (BSC.pack git)
      location <- OS.fromBytes (BSC.pack directory)
      source <- either (fail . show) pure (parseSourceRef "refs/heads/agents")
      report <- inspectCommittedState (runGitPosix executable) location source
      require (case classifyCommittedState (stateFindings report) of
        IndeterminateCommittedState _ -> True
        _ -> False) "unsupported version was classified as determinate"
      status <- cliOk candidate directory ["status"]
      require (isInfixOf "indeterminate" status &&
        isInfixOf "Unsupported config version 2" status) "status hid unsupported branch"
      _ <- cliFail candidate directory ["check"]
      _ <- cliFail candidate directory ["deploy", "--branch", "agents"]
      -- Retaining the marker must not allow native Git to move an unknown-version branch.
      _ <- gitOk directory ["config", "hook.gaw-reference-transaction.event", "reference-transaction"]
      _ <- gitOk directory ["config", "hook.gaw-reference-transaction.command", candidate ++ " --reference-transaction"]
      _ <- gitOk directory ["config", "hook.gaw-reference-transaction.enabled", "true"]
      before <- gitOk directory ["rev-parse", "HEAD"]
      writeFile (directory </> "another") "same marker\n"
      _ <- gitOk directory ["add", "--", "another"]
      _ <- failure directory git ["-c", "commit.gpgsign=false", "commit", "-q", "-m", "must reject"]
      after <- gitOk directory ["rev-parse", "HEAD"]
      require (before == after) "unsupported-version protection was weakened"
