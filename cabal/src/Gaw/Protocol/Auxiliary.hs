{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.Auxiliary
  ( AuxiliaryReport (..), auxiliaryValid, deletionProblems, deletionInput
  , abandonmentWarning, renderAuxiliaryReport
  ) where

import qualified Data.ByteString as BS
import Gaw.Protocol.Ref
import Gaw.Protocol.State

data AuxiliaryReport = AuxiliaryReport
  { auxiliarySource :: RefName
  , auxiliaryTip :: ObjectId
  , auxiliaryState :: StateReport
  , observedSelector :: RefState
  , observedFormalTip :: Maybe ObjectId
  , formalStateValid :: Bool
  , auxiliaryRetained :: Maybe Bool
  , auxiliaryWorktrees :: [BS.ByteString]
  } deriving (Eq, Show)

auxiliaryValid :: AuxiliaryReport -> Bool
auxiliaryValid report = case classifyCommittedState (stateFindings (auxiliaryState report)) of
  ValidCommittedState _ -> True
  _ -> False

deletionProblems :: Bool -> AuxiliaryReport -> [BS.ByteString]
deletionProblems force report =
  ["Auxiliary committed state is invalid or indeterminate" | not (auxiliaryValid report)] ++
  ["Associated worktrees remain: " <> BS.intercalate ", " (auxiliaryWorktrees report)
    | not (null (auxiliaryWorktrees report))] ++
  ["The selector must reach valid formal GAW committed state" | not force && not (formalStateValid report)] ++
  ["The Auxiliary tip is not retained in the selected formal GAW history"
    | not force && auxiliaryRetained report /= Just True]

-- All three observations are verified by one transaction, without dereferencing
-- a branch that changed into a symbolic ref between inspection and deletion.
deletionInput :: Bool -> AuxiliaryReport -> BS.ByteString
deletionInput force report = "option no-deref\0" <> formalChecks <>
  "delete " <> refNameBytes (auxiliarySource report) <> "\0" <>
  objectIdBytes (auxiliaryTip report) <> "\0"
  where
    formalChecks = if force then "" else case (observedSelector report, observedFormalTip report) of
      (RefSymbolic formal, Just tip) ->
        "symref-verify refs/gaw/HEAD\0" <> refNameBytes formal <> "\0verify " <>
        refNameBytes formal <> "\0" <> objectIdBytes tip <> "\0"
      _ -> "" -- Callers must reject deletionProblems before executing this input.

abandonmentWarning :: Bool -> AuxiliaryReport -> [BS.ByteString]
abandonmentWarning force report =
  ["Active abandonment of Auxiliary history; continued reachability after deletion is not guaranteed."
    | force && auxiliaryRetained report /= Just True]

renderAuxiliaryReport :: AuxiliaryReport -> BS.ByteString
renderAuxiliaryReport report = BS.concat
  [ "Auxiliary branch: ", refNameBytes (auxiliarySource report), "\n"
  , "Auxiliary tip: ", objectIdBytes (auxiliaryTip report), "\n"
  , "History structure: ", if auxiliaryValid report then "valid\n" else "invalid or indeterminate\n"
  , BS.concat ["  " <> findingDetail f <> "\n" | f <- stateFindings (auxiliaryState report),
      findingStatus f == FindingError]
  , "Formal selector: ", case observedSelector report of
      RefSymbolic target -> refNameBytes target
      RefMissing -> "absent"
      _ -> "invalid"
  , "\nFormal tip: ", maybe "unknown" objectIdBytes (observedFormalTip report)
  , "\nSafe deletion: ", if null problems then "ready\n" else "not ready\n"
  , BS.concat ["  " <> problem <> "\n" | problem <- problems]
  ]
  where problems = deletionProblems False report
