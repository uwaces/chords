module Base.Chord.Chord
  ( Chord
  , chordFrom
  ) where

import Base.Chord.ChordShape
import Base.Chord.ChordSymbol
import Base.Chord.Extension
import Base.Chord.HighestNatural
import Base.Chord.Root
import Base.Chord.Sus

import Base.Core.Quality.CQuality

import Base.Class.Chordal
import Base.Class.Rooted

data Chord = Chord { getSymbol :: ChordSymbol
                   , getNotes :: [Root]
                   } deriving Show

instance Chordal Chord where
  quality = quality . getSymbol
  highestNatural = highestNatural . getSymbol
  extensions = extensions . getSymbol
  suspension = suspension . getSymbol
  toIntervals = undefined

instance Rooted Chord where
  root = root . getSymbol
  toNotes = getNotes

-- TODO: Actually get `chordToNotes` somewhere where we can put the real list
-- of notes here
chordFrom :: Root -> Quality -> HighestNatural -> [Extension] -> Sus -> Chord
chordFrom r q hn exts s =
  Chord { getSymbol = chordSymbolFrom r $ chordShapeFrom q hn exts s
        , getNotes = []
        }
