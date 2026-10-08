{-# LANGUAGE OverloadedStrings #-}

module Gaw.Protocol.SExpr
  ( SExpr (..)
  , SyntaxError (..)
  , parseSExpr
  ) where

import qualified Data.ByteString as BS
import Data.Char (ord)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

data SyntaxError = SyntaxError T.Text | SyntaxLimit T.Text
  deriving (Eq, Show)

data SExpr = SList [SExpr] | SKeyword T.Text | SString T.Text
  deriving (Eq, Show)

parseSExpr :: BS.ByteString -> Either SyntaxError SExpr
parseSExpr bytes
  | BS.length bytes > 65536 = Left (SyntaxLimit "Config exceeds 65536 octets")
  | otherwise = do
      input <- either (const (Left (SyntaxError "Config is not valid UTF-8"))) Right
        (TE.decodeUtf8' bytes)
      if T.isPrefixOf "\xfeff" input
        then Left (SyntaxError "UTF-8 BOM is not allowed")
        else do
          (form, rest) <- parseForm 0 (skipTrivia (T.unpack input))
          if null (skipTrivia rest)
            then Right form
            else Left (SyntaxError "Config contains multiple forms")

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
        _ -> Left (SyntaxError "Unsupported token")

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

