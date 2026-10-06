module Gaw.System.Clock
  ( Clock (..)
  , posixClock
  ) where

import Data.Time.Clock.POSIX (getPOSIXTime)

newtype Clock m = Clock { unixTimestamp :: m Integer }

posixClock :: Clock IO
posixClock = Clock (floor <$> getPOSIXTime)
