{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.SExpr
  ( SExpr (..)
  , SyntaxError (..)
  , LeadingVersion (..)
  , parseSExpr
  , scanLeadingVersion
  ) where

import qualified Data.ByteString as BS
import Data.Char (ord)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

data SyntaxError = SyntaxError T.Text | SyntaxLimit T.Text
  deriving (Eq, Show)

data SExpr = SList [SExpr] | SKeyword T.Text | SString T.Text | SInteger Integer
  deriving (Eq, Show)

data LeadingVersion = NoLeadingVersion | LeadingVersionAtom T.Text | MalformedLeadingVersion
  deriving (Eq, Show)

parseSExpr :: BS.ByteString -> Either SyntaxError SExpr
parseSExpr bytes = do
  input <- decodeInput bytes
  (form, rest) <- parseForm 0 (skipTrivia input)
  if null (skipTrivia rest)
    then Right form
    else Left (SyntaxError "Config contains multiple forms")

-- Only a leading :version opts into the forward-compatible envelope. The
-- remaining forms are scanned for shared lexical/structural safety, without
-- asking the current S-expression parser to understand future syntax.
scanLeadingVersion :: BS.ByteString -> Either SyntaxError LeadingVersion
scanLeadingVersion bytes = do
  input <- decodeInput bytes
  let top = skipTrivia input
  case top of
    '(':rest ->
      let (first, afterFirst) = span (not . delimiter) (skipTrivia rest)
       in if first == ":version"
            then do
              (_, trailing) <- scanForm 0 top
              if null (skipTrivia trailing)
                then Right (versionAtom (skipTrivia afterFirst))
                else Left (SyntaxError "Config contains multiple forms")
            else Right NoLeadingVersion
    _ -> Right NoLeadingVersion
  where
    versionAtom input = case input of
      [] -> MalformedLeadingVersion
      c:_ | c == '(' || c == ')' || c == '"' -> MalformedLeadingVersion
      _ -> case takeWhile (not . delimiter) input of
        [] -> MalformedLeadingVersion
        atom -> LeadingVersionAtom (T.pack atom)

decodeInput :: BS.ByteString -> Either SyntaxError String
decodeInput bytes
  | BS.length bytes > 65536 = Left (SyntaxLimit "Config exceeds 65536 octets")
  | otherwise = do
      input <- either (const (Left (SyntaxError "Config is not valid UTF-8"))) Right
        (TE.decodeUtf8' bytes)
      if T.isPrefixOf "\xfeff" input
        then Left (SyntaxError "UTF-8 BOM is not allowed")
        else Right (T.unpack input)

scanForm :: Int -> String -> Either SyntaxError ((), String)
scanForm _ [] = Left (SyntaxError "Config is empty or incomplete")
scanForm depth ('(':rest)
  | depth >= 16 = Left (SyntaxLimit "List nesting exceeds 16")
  | otherwise = scanList (depth + 1) rest
scanForm _ (')':_) = Left (SyntaxError "Unmatched closing parenthesis")
scanForm _ ('"':rest) = do
  (_, trailing) <- parseString [] rest
  Right ((), trailing)
scanForm _ input =
  let (atom, rest) = span (not . delimiter) input
   in if null atom || any invalidAtomChar atom
        then Left (SyntaxError "Invalid config atom")
        else Right ((), rest)
  where
    invalidAtomChar c = ord c < 32 || ord c == 127 || c == '"'

scanList :: Int -> String -> Either SyntaxError ((), String)
scanList depth input = case skipTrivia input of
  [] -> Left (SyntaxError "Unclosed list")
  ')':rest -> Right ((), rest)
  rest -> do
    (_, next) <- scanForm depth rest
    scanList depth next

parseForm :: Int -> String -> Either SyntaxError (SExpr, String)
parseForm _ [] = Left (SyntaxError "Config is empty or incomplete")
parseForm depth ('(':rest)
  | depth >= 16 = Left (SyntaxLimit "List nesting exceeds 16")
  | otherwise = parseList (depth + 1) [] rest
parseForm _ (')':_) = Left (SyntaxError "Unmatched closing parenthesis")
parseForm _ ('"':rest) = parseString [] rest
parseForm _ input =
  let (token, rest) = span (not . delimiter) input
   in case token of
        ':':keyword -> Right (SKeyword (T.pack keyword), rest)
        _ | decimal token -> Right (SInteger (read token), rest)
          | otherwise -> Left (SyntaxError "Unsupported token")
  where
    decimal [] = False
    decimal ('-':digits) = not (null digits) && all asciiDigit digits
    decimal digits = all asciiDigit digits
    asciiDigit c = c >= '0' && c <= '9'

parseList :: Int -> [SExpr] -> String -> Either SyntaxError (SExpr, String)
parseList depth acc input = case skipTrivia input of
  [] -> Left (SyntaxError "Unclosed list")
  ')':rest -> Right (SList (reverse acc), rest)
  rest -> do
    (form, next) <- parseForm depth rest
    parseList depth (form : acc) next

parseString :: [Char] -> String -> Either SyntaxError (SExpr, String)
parseString _ [] = Left (SyntaxError "Unterminated string")
parseString acc ('"':rest) = Right (SString (T.pack (reverse acc)), rest)
parseString acc ('\\':escaped:rest)
  | escaped == '"' || escaped == '\\' = parseString (escaped : acc) rest
  | otherwise = Left (SyntaxError "Unsupported string escape")
parseString _ ['\\'] = Left (SyntaxError "Incomplete string escape")
parseString acc (c:rest)
  | ord c < 32 || ord c == 127 = Left (SyntaxError "Literal ASCII control character in string")
  | otherwise = parseString (c : acc) rest

delimiter :: Char -> Bool
delimiter c = c `elem` (" \t\n\r();" :: String)

skipTrivia :: String -> String
skipTrivia input = case input of
  c:rest | c `elem` (" \t\n\r" :: String) -> skipTrivia rest
  ';':rest -> skipTrivia (dropWhile (/= '\n') rest)
  _ -> input
