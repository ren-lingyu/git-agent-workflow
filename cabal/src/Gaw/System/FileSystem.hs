module Gaw.System.FileSystem
  ( FileSystem (..)
  , posixFileSystem
  , readPosixFile
  ) where

import Control.Exception (bracket)
import qualified Data.ByteString as BS
import qualified System.Posix.Files.ByteString as Files
import qualified System.Posix.IO as IO
import qualified System.Posix.IO.ByteString as PosixIO
import qualified System.OsString.Posix as OS
import System.OsPath.Posix (PosixPath)
import System.IO (hClose)

-- Paths crossing this boundary are opaque POSIX path bytes.
data FileSystem m = FileSystem
  { pathExists :: BS.ByteString -> m Bool
  , pathFromBytes :: BS.ByteString -> m PosixPath
  }

posixFileSystem :: FileSystem IO
posixFileSystem = FileSystem Files.fileExist OS.fromBytes

readPosixFile :: BS.ByteString -> IO BS.ByteString
readPosixFile path = do
  fd <- PosixIO.openFd path IO.ReadOnly IO.defaultFileFlags
  bracket (IO.fdToHandle fd) hClose BS.hGetContents
