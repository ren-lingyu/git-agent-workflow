{-# LANGUAGE OverloadedStrings #-}

module Gaw.System.Git
  ( Git (..)
  , GitInvocation (..)
  , GitResult (..)
  , runGitPosix
  ) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, catch, evaluate, try)
import Control.Monad (void)
import qualified Data.ByteString as BS
import qualified System.OsString.Posix as OS
import System.OsPath.Posix (PosixPath)
import qualified System.Posix.Env.ByteString as Env
import System.Posix.IO (closeFd, createPipe, dupTo, fdToHandle, stdError, stdInput, stdOutput)
import qualified System.Posix.Process.PosixString as Process
import System.Posix.Process (ProcessStatus (..), getProcessStatus)
import System.Exit (ExitCode (..))
import System.IO (hClose)

data GitInvocation = GitInvocation
  { gitDirectory :: PosixPath
  , gitArguments :: [BS.ByteString]
  , gitInput :: Maybe BS.ByteString
  , gitEnvironment :: [(BS.ByteString, BS.ByteString)]
  } deriving (Eq, Show)

data GitResult = GitResult
  { gitExitCode :: Int
  , gitStdout :: BS.ByteString
  , gitStderr :: BS.ByteString
  } deriving (Eq, Show)

newtype Git m = Git
  { runGit :: GitInvocation -> m GitResult
  }

runGitPosix :: PosixPath -> Git IO
runGitPosix executable = Git (invoke executable)

invoke :: PosixPath -> GitInvocation -> IO GitResult
invoke executable invocation = do
  mapM_ validateBinding (gitEnvironment invocation)
  inherited <- Env.getEnvironment
  let baseEnvironment = filter (not . excluded . fst) inherited
      overrides = [("GIT_CONFIG_NOSYSTEM", "1"), ("GIT_CONFIG_SYSTEM", "/dev/null"),
                   ("GIT_CONFIG_GLOBAL", "/dev/null")]
      environment = foldl replace baseEnvironment (overrides ++ gitEnvironment invocation)
  flag <- OS.fromBytes "-C"
  args <- traverse OS.fromBytes (gitArguments invocation)
  let actualArgs = flag : gitDirectory invocation : args
  posixEnvironment <- traverse (\(key, value) -> (,) <$> OS.fromBytes key <*> OS.fromBytes value) environment
  (stdinRead, stdinWrite) <- createPipe
  (stdoutRead, stdoutWrite) <- createPipe
  (stderrRead, stderrWrite) <- createPipe
  pid <- Process.forkProcess $ do
    closeFd stdinWrite
    closeFd stdoutRead
    closeFd stderrRead
    void (dupTo stdinRead stdInput)
    void (dupTo stdoutWrite stdOutput)
    void (dupTo stderrWrite stdError)
    closeFd stdinRead
    closeFd stdoutWrite
    closeFd stderrWrite
    Process.executeFile executable True actualArgs (Just posixEnvironment)
      `catch` childFailure
  closeFd stdinRead
  closeFd stdoutWrite
  closeFd stderrWrite
  inputHandle <- fdToHandle stdinWrite
  outputHandle <- fdToHandle stdoutRead
  errorHandle <- fdToHandle stderrRead
  outputVar <- newEmptyMVar
  errorVar <- newEmptyMVar
  void $ forkIO $ do
    bytes <- BS.hGetContents outputHandle
    void (evaluate (BS.length bytes))
    putMVar outputVar bytes
  void $ forkIO $ do
    bytes <- BS.hGetContents errorHandle
    void (evaluate (BS.length bytes))
    putMVar errorVar bytes
  _ <- try (maybe (pure ()) (BS.hPut inputHandle) (gitInput invocation) >> hClose inputHandle)
    :: IO (Either SomeException ())
  output <- takeMVar outputVar
  errors <- takeMVar errorVar
  status <- getProcessStatus True False pid
  pure (GitResult (exitNumber status) output errors)

childFailure :: SomeException -> IO a
childFailure _ = Process.exitImmediately (ExitFailure 127)

exitNumber :: Maybe ProcessStatus -> Int
exitNumber status = case status of
  Just (Exited ExitSuccess) -> 0
  Just (Exited (ExitFailure code)) -> code
  Just (Terminated signal _) -> 128 + fromIntegral signal
  Just (Stopped signal) -> 128 + fromIntegral signal
  Nothing -> 128

excluded :: BS.ByteString -> Bool
excluded name = "GIT_" `BS.isPrefixOf` name || name == "EMAIL"

replace :: [(BS.ByteString, BS.ByteString)] -> (BS.ByteString, BS.ByteString)
  -> [(BS.ByteString, BS.ByteString)]
replace environment binding = binding : filter ((/= fst binding) . fst) environment

validateBinding :: (BS.ByteString, BS.ByteString) -> IO ()
validateBinding (name, _)
  | BS.null name || BS.elem 61 name || BS.elem 0 name =
      ioError (userError "Invalid Git environment binding")
  | name `elem` ["GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_SYSTEM", "GIT_CONFIG_GLOBAL"] =
      ioError (userError "Protected Git environment binding")
  | otherwise = pure ()
