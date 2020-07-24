module Lib
  ( chordToIntervals
  , chordToNotes
  ) where

import Base.Core.Quality
import Base.Chord

import Base.Chord.Chord
import Base.Chord.Extension
import Base.Chord.HighestNatural
import Base.Chord.Root
import Base.Chord.Sus

import Interval
    ( Interval(..)
    , IQuality(..)
    , (<+>)
    , (<->)
    , defaultIQuality
    , jumpIntervalFromNote
    , intervalToDistance
    )
import Scale (Scale(..), scaleToIntervals)
import Data.Set(Set(..))
import qualified Data.Set as S
import Data.Map.Strict (Map, insert, fromList, toList, (!), delete, (!?))
import Data.Maybe (fromJust)


chordToNotes :: Chord -> [Root]
chordToNotes chord =
  flip jumpIntervalFromNote (getChordRoot chord) <$> S.toList (chordToIntervals chord)


chordToIntervals :: Chord -> Set Interval
chordToIntervals chord =
  let
    baseScale = highestNaturalToIntervals (getHighestNatural chord) $ qualityToIntervals $ getQuality chord
    intervals = susIntervals (extendIntervals baseScale $ getExtensions chord) $ getSus chord
  in
    foldr S.insert S.empty intervals


type HeliotonicScale = Map Int Interval


qualityToIntervals :: Quality -> HeliotonicScale
qualityToIntervals qual = fromList $ zip [1..7] $ scaleToIntervals $ qualityToScale qual
  where
    qualityToScale :: Quality -> Scale
    qualityToScale Major = SLydian
    qualityToScale Minor = SDorian
    qualityToScale Dominant = SMixolydian
    qualityToScale (Augmented _) = SAugmentedQuality
    qualityToScale (Diminished _) = SDiminishedQuality


susIntervals :: HeliotonicScale -> Sus -> HeliotonicScale
susIntervals scale s = maybe scale (\i -> insert i (Interval (defaultIQuality i) i) $ delete 3 scale) (getMaybeDeg s)


extendIntervals :: HeliotonicScale -> [Extension] -> HeliotonicScale
extendIntervals = foldr $ flip extendInterval
  where
  extendInterval :: HeliotonicScale -> Extension -> HeliotonicScale
  extendInterval scale ext = insert deg (Interval (defaultIQuality deg) deg <+> shift) scale
    where
      deg   = degree ext
      shift = extSign ext

highestNaturalToIntervals :: HighestNatural -> HeliotonicScale -> HeliotonicScale
highestNaturalToIntervals hn scale =
  let
    scaleInts = getIntervals subset scale
  in
    if isMajor hn then
      insertMajorSeven scaleInts
    else
      scaleInts
  where
    subset =
      let
        deg = getDegree hn
      in
        if even $ getDegree hn then
          [1, 3, 5, deg]
        else
          [1, 3 .. deg]

    getIntervals :: [Int] -> HeliotonicScale -> HeliotonicScale
    getIntervals ints hts = fromList $ map ($ hts) (getInterval <$> ints)

    getInterval :: Int -> HeliotonicScale -> (Int, Interval)
    getInterval int hts =
      let
        interval = hts !? ((int-1) `mod` 7 + 1)
      in
        (int, fromJust interval)

    insertMajorSeven :: HeliotonicScale -> HeliotonicScale
    insertMajorSeven hts = insert 7 (Interval IMajor 7) hts
