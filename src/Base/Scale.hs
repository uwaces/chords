module Base.Scale
  ( Scale(..)
  , BaseMode(..)
  , Mode(..)
  , baseModeIntervals
  , modeToIntervals
  , scaleToNotes
  , modalDistance
  , modesToExts
  , intervalsToMode
  , zipToIntervalSet
  , isSubsetMode
  , getSubsetModeByDegree
  , major
  , minor
  , scaleLength
  ) where

import Base.Core.Quality.IQuality
import Base.Core.Note
import Base.Core.Interval
import Base.Core.Accidental(Accidental(..), impliedShift, shiftToAcc, natural)
import Base.Scale.Extension
import Control.Monad (filterM, zipWithM)
import Data.List (sort, sortBy, intercalate, takeWhile)
import Data.Set(Set(..), fromList, toAscList, elemAt, insert, delete, mapMonotonic, isSubsetOf, toList)
import qualified Data.Set as S(filter, map)
import Data.Maybe(fromJust)
import Data.Function

data Scale = Scale Note Mode

instance Show Scale where
  show (Scale note mode) = show note ++ " " ++ show mode

data Mode = Mode BaseMode [Extension]

instance Show Mode where
  show (Mode base exts) = show base
                       --Add a space if there are extensions...
                       ++ if null exts then "" else " "
                       --Add extensions separated by a comma...
                       ++ intercalate ", " (show <$> exts)

data BaseMode
  = Lydian
  | Dorian
  | Mixolydian
  | AugmentedQuality
  | DiminishedQuality
  | Ionian
  | Aeolian
  | Phrygian
  | Locrian
  | MelodicMinor
  | LydianAug
  | LydianDom
  | Altered
  | HarmonicMinor
  | PhrygianDom
  | DoubleHarmonicMinor
  | HarmonicMajor
  | DoubleHarmonicMajor
  deriving (Show, Enum, Eq)

major :: Note -> Scale
major key = Scale key (Mode Ionian [])

minor :: Note -> Scale
minor key = Scale key (Mode Aeolian [])

nthDegreeIntervals :: Set Interval -> Int -> Set Interval
nthDegreeIntervals ints n = S.map (|-| noteInterval) ints
  where
   noteInterval = toAscList ints !! (n - 1)

zipToIntervalSet :: [Quality] -> [Int] -> Maybe (Set Interval)
zipToIntervalSet quals sizes =
  do ints <- zipWithM intervalFrom quals sizes
     return $ fromList ints

baseModeIntervals :: BaseMode -> Set Interval
baseModeIntervals bm = if fromScratch then
                         fromJust $ zipToIntervalSet bmQualities [1 .. 7]
                       else
                         let
                           (mode, shift) = modeAndShift
                         in
                           nthDegreeIntervals (baseModeIntervals mode) shift
  where
    -- Discriminate between BaseModes for which we build the intervals from
    -- scratch and those that are computed from some other interval set
    fromScratch :: Bool
    fromScratch = bm `elem` [ Ionian
                            , AugmentedQuality
                            , DiminishedQuality
                            , MelodicMinor
                            , HarmonicMinor
                            , DoubleHarmonicMinor
                            , HarmonicMajor
                            , DoubleHarmonicMajor
                            ]

    -- The interval qualities for the modal interval sets built from scratch
    bmQualities :: [Quality]
    bmQualities =
      case bm of
        Ionian ->
          [Perfect, Major, Major, Perfect, Perfect, Major, Major]
        AugmentedQuality ->
          [Perfect, Major, Major, Augmented 1, Augmented 1, Major, Minor]
        DiminishedQuality ->
          [Perfect, Major, Minor, Perfect, Diminished 1, Minor, Diminished 1]
        MelodicMinor ->
          [Perfect, Major, Minor, Perfect, Perfect, Major, Major]
        HarmonicMinor ->
          [Perfect, Major, Minor, Perfect, Perfect, Minor, Major]
        DoubleHarmonicMinor ->
          [Perfect, Major, Minor, Augmented 1, Perfect, Minor, Major]
        HarmonicMajor ->
          [Perfect, Major, Major, Perfect, Perfect, Minor, Major]
        DoubleHarmonicMajor ->
          [Perfect, Minor, Major, Perfect, Perfect, Minor, Major]

    -- The starting mode and shift for modal interval sets built from other
    -- interval sets
    modeAndShift :: (BaseMode, Int)
    modeAndShift =
      case bm of
        Dorian      -> (Ionian, 2)
        Phrygian    -> (Ionian, 3)
        Lydian      -> (Ionian, 4)
        Mixolydian  -> (Ionian, 5)
        Aeolian     -> (Ionian, 6)
        Locrian     -> (Ionian, 7)
        LydianAug   -> (MelodicMinor, 3)
        LydianDom   -> (MelodicMinor, 4)
        Altered     -> (MelodicMinor, 7)
        PhrygianDom -> (HarmonicMinor, 5)

modeToIntervals :: Mode -> Set Interval
modeToIntervals (Mode baseMode exts) =
  foldr extIntervals (baseModeIntervals baseMode) exts
  where
    extIntervals :: Extension -> Set Interval -> Set Interval
    extIntervals ext intSet = insert (oldInt <+> impliedShift (getAccidental ext)) (delete oldInt intSet)
      where
        -- TODO: If there isn't only one interval of a certain degree, the mode is
        -- ambiguously constructed and we should give a warning.
        oldInt = elemAt 0 (S.filter (\a -> getSize a == getDegree ext) intSet)

scaleToNotes :: Scale -> [Note]
scaleToNotes (Scale note mode) = toList $ mapMonotonic (`jumpIntervalFromNote` note) (modeToIntervals mode)

scaleLength :: Scale -> Int
scaleLength s = length $ scaleToNotes s

modalDistance :: Set Interval -> Set Interval -> Int
modalDistance mode1 mode2 = sum $ intDistance <$> (zip `on` toAscList) mode1 mode2
  where
    intDistance :: (Interval, Interval) -> Int
    intDistance (i1, i2) = abs $ fromJust $ intervalToDistance (i1 |-| i2)


modesToExts :: Set Interval -> Set Interval -> [Extension]
modesToExts mode1 mode2 =
  let
    zippedInts = zip (toAscList mode1) (toAscList mode2)
    intervalDiffToAcc :: Interval -> Interval -> Accidental
    intervalDiffToAcc i1 i2 = shiftToAcc $ fromJust $ intervalToDistance $ i2 |-| i1
    accToExtList :: Accidental -> Int -> [Extension] -> [Extension]
    accToExtList accidental degree
      | accidental == natural = id
      | otherwise             = (scaleExtensionFrom accidental degree :)
  in
    foldr (\(i1,i2) exts -> accToExtList (intervalDiffToAcc i2 i1) (getSize i1) exts)
          []
          zippedInts

intervalsToMode :: Set Interval -> [Mode]
intervalsToMode intSet =
  let
    eqOnSize :: BaseMode -> Bool
    eqOnSize bm =
      ((==) `on` S.map getSize) (baseModeIntervals bm) intSet

    sameDegreeModes :: [BaseMode]
    sameDegreeModes = filter eqOnSize [Lydian ..]

    distanceFromIntSet :: Set Interval -> BaseMode -> Int
    distanceFromIntSet iSet mode = modalDistance iSet $ baseModeIntervals mode

    sortedModes :: [BaseMode]
    sortedModes = sortBy (compare `on` distanceFromIntSet intSet) sameDegreeModes

    exts :: [[Extension]]
    exts =
      let
        bmIntss = baseModeIntervals <$> sortedModes
      in
        modesToExts intSet <$> bmIntss
  in
    filter (\mode -> numAlteredDegsInMode mode == minimum (length <$> exts)) $ uncurry Mode <$> zip sortedModes exts

isSubsetMode :: Set Interval -> Set Interval -> Bool
isSubsetMode = isSubsetOf

getSubsetModeByDegree :: Set Interval -> Set Int -> Set Interval
getSubsetModeByDegree mode degs = S.filter (\i -> getSize i `elem` degs) mode

numAlteredDegsInMode :: Mode -> Int
numAlteredDegsInMode (Mode base exts) = length exts
