module Gaw.Protocol.State
  ( FindingName (..)
  , FindingStatus (..)
  , Certainty (..)
  , StateFinding (..)
  , CommittedState (..)
  , StateReport (..)
  , classifyCommittedState
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Config (Config)
import Gaw.Protocol.Ref (ObjectId, RefName)

data FindingName = Head | HeadConfig | HeadWorkspace | ProjectParents
  deriving (Eq, Ord, Show)

data FindingStatus = FindingOk | FindingError | FindingSkipped
  deriving (Eq, Show)

data Certainty = Determinate | Indeterminate
  deriving (Eq, Show)

data StateFinding = StateFinding
  { findingName :: FindingName
  , findingStatus :: FindingStatus
  , findingDetail :: BS.ByteString
  , findingCertainty :: Certainty
  } deriving (Eq, Show)

data CommittedState
  = ValidCommittedState [StateFinding]
  | InvalidCommittedState [StateFinding]
  | IndeterminateCommittedState [StateFinding]
  deriving (Eq, Show)

data StateReport = StateReport
  { stateSource :: Maybe RefName
  , stateCommit :: Maybe ObjectId
  , stateTree :: Maybe ObjectId
  , stateConfig :: Maybe Config
  , stateFindings :: [StateFinding]
  } deriving (Eq, Show)

classifyCommittedState :: [StateFinding] -> CommittedState
classifyCommittedState findings
  | not (any ((== FindingError) . findingStatus) findings) = ValidCommittedState findings
  | any ((== Indeterminate) . findingCertainty) findings = IndeterminateCommittedState findings
  | otherwise = InvalidCommittedState findings
