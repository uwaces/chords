module Main where

import Lib
import Parser
import Chord
import Control.Monad (unless)

main :: IO ()
main =
  do
    chordStr <- getLine
    unless (chordStr == "q") $ readEvalPrint chordStr >> main

readEvalPrint :: String -> IO ()
readEvalPrint chordStr =
  do print chordStr
     let xs = Parser.parseChord chordStr
     print xs
     print $ canonicalizeChord <$> xs
     print $ show . Lib.chordToNotes . canonicalizeChord <$> xs
