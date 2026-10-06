{-# LANGUAGE TemplateHaskell #-}

module Gaw.System.ExternalGit (gitExecutable) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.Maybe (fromMaybe)
import Language.Haskell.TH.Syntax (lift, runIO)
import System.Environment (lookupEnv)

gitExecutable :: BS.ByteString
gitExecutable = BSC.pack $(do
  executable <- runIO (fromMaybe "git" <$> lookupEnv "GIT")
  lift executable)
