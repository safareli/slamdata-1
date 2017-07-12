{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Workspace.Card.InsertableCardType where

import SlamData.Prelude

import Data.Array as Array
import Data.Foldable as Foldable
import Data.String as String
import Data.Variant (on)

import SlamData.Workspace.Card.CardType as CT
import SlamData.Workspace.Card.Port as Port
import SlamData.Workspace.Card.CardType (CardType)
import SlamData.Workspace.Card.Port (Port)

import Utils as Utils

data InsertableCardType
  = CacheCard
  | DraftboardCard
  | OpenCard
  | QueryCard
  | SearchCard
  | SetupChartCard
  | SetupFormCard
  | SetupDownloadCard
  | SetupMarkdownCard
  | SetupVariablesCard
  | ShowDownloadCard
  | ShowMarkdownCard
  | TableCard
  | TroubleshootCard
  | TabsCard
  | StructureEditorCard
  | SetupGeoChartCard
  | ShowVizCard

data InsertableCardIOType
  = Chart
  | GeoChart
  | Form
  | Data
  | Download
  | Markdown
  | Variables
  | Terminal
  | None

derive instance eqInsertableCardType ∷ Eq InsertableCardType
derive instance eqInsertableCardIOType ∷ Eq InsertableCardIOType

-- Cards can have multiple input types
inputs ∷ Array (InsertableCardType × (Array InsertableCardIOType))
inputs =
  [ CacheCard × [ Data ]
  , DraftboardCard × [ None ]
  , OpenCard × [ None, Variables ]
  , QueryCard × [ None, Data, Variables ]
  , SearchCard × [ Data ]
  , SetupChartCard × [ Data ]
  , SetupGeoChartCard × [ Data ]
  , SetupDownloadCard × [ Data ]
  , SetupFormCard × [ Data ]
  , SetupMarkdownCard × [ None, Variables ]
  , SetupVariablesCard × [ None ]
  , ShowDownloadCard × [ Download ]
  , ShowMarkdownCard × [ Markdown ]
  , TableCard × [ Data ]
  , TroubleshootCard × [ Chart, Form, Data, Download, Markdown, Variables ]
  , TabsCard × [ None ]
  , StructureEditorCard × [ Data ]
  , ShowVizCard × [ GeoChart, Chart, Form ]
  ]

-- Cards only have one output type, treat this as a Map or turn it into one.
outputs ∷ Array (InsertableCardType × InsertableCardIOType)
outputs =
  [ CacheCard × Data
  , DraftboardCard × Variables
  , OpenCard × Data
  , QueryCard × Data
  , SearchCard × Data
  , SetupChartCard × Chart
  , SetupFormCard × Form
  , SetupDownloadCard × Download
  , SetupMarkdownCard × Markdown
  , SetupVariablesCard × Variables
  , ShowDownloadCard × Download
  , ShowMarkdownCard × Variables
  , TableCard × Data
  , TroubleshootCard × Variables
  , StructureEditorCard × Data
  , ShowVizCard × Data
  ]

cardsToExcludeFromPaths ∷ Array InsertableCardType
cardsToExcludeFromPaths =
  [ TroubleshootCard
  , TableCard
  , DraftboardCard
  , CacheCard
  , TabsCard
  ]

contains ∷ ∀ a. (Eq a) ⇒ a → Array a → Boolean
contains x = isJust ∘ Array.elemIndex x

takesInput ∷ InsertableCardIOType → InsertableCardType → Boolean
takesInput io card = Foldable.elem card $ cardsThatTakeInput io

inputsFor ∷ InsertableCardType → Array InsertableCardIOType
inputsFor card =
  Array.concat $ map snd $ Array.filter (eq card ∘ fst) inputs

outputFor ∷ InsertableCardType → Maybe InsertableCardIOType
outputFor card =
  Utils.singletonValue
    Nothing
    (const Nothing)
    (map snd $ Array.filter (eq card ∘ fst) outputs)

cardsThatOutput ∷ InsertableCardIOType → Array InsertableCardType
cardsThatOutput io =
  map fst $ Array.filter (eq io ∘ snd) outputs

cardsThatTakeInput ∷ InsertableCardIOType → Array InsertableCardType
cardsThatTakeInput io =
  map fst $ Array.filter (contains io ∘ snd) inputs

type Path =
  { c ∷ Array InsertableCardType, io ∷ Array InsertableCardIOType, f ∷ Boolean }

purePath ∷ InsertableCardIOType → Path
purePath io =
  { c: [], io: [io], f: false }

cardPathsFromPaths ∷ Array Path → Array (Array InsertableCardType)
cardPathsFromPaths = map _.c

allPathsFinished ∷ Array Path → Boolean
allPathsFinished = Foldable.all _.f

cardPathsBetween ∷ InsertableCardIOType → InsertableCardType → Array (Array InsertableCardType)
cardPathsBetween fromIO toCard =
  Array.filter (not ∘ Foldable.elem toCard) $ cardPathsFromPaths $ pathsBetween fromIO toCard

pathsBetween ∷ InsertableCardIOType → InsertableCardType → Array Path
pathsBetween fromIO toCard =
  Array.concat $ pathsBetweenIO fromIO <$> inputsFor toCard

cardPathNeeded ∷ Array (Array InsertableCardType) → Boolean
cardPathNeeded cardPaths =
  not $ Array.null cardPaths || [] `Foldable.elem` cardPaths

possibleToGetTo ∷ InsertableCardIOType → InsertableCardType → Boolean
possibleToGetTo io card =
  not $ Array.null $ Array.concat $ pathsBetweenIO io <$> inputsFor card

-- This produces an array of sensible suggested paths. It excludes paths which
-- include cards in the cardsToExcludeFromPaths array and paths which include
-- the same io type more than twice.
--
-- Allowing the same io type twice rather than only once allows sets of cards
-- such as (SearchCard) and (SetupFormCard, ShowFormCard) to be included in
-- paths.
--
-- Not allowing the same data type more than twice prevents duplicate sets of
-- cards such as (SearchCard) and (SetupFormCard, ShowFormCard) as well as
-- preventing infinite loops.
pathsBetweenIO ∷ InsertableCardIOType → InsertableCardIOType → Array Path
pathsBetweenIO fromIO toIO =
  go $ [ purePath toIO ]
  where
  go ∷ Array Path → Array Path
  go paths | allPathsFinished paths = paths
  go paths | otherwise =
    go $ Array.concat $ expandPath fromIO <$> paths

expandPath ∷ InsertableCardIOType → Path → Array Path
expandPath fromIO initialPath | initialPath.f =
  [ initialPath ]
expandPath fromIO initialPath | maybe true (eq fromIO) (Array.head initialPath.io) =
  [ initialPath { f = true } ]
expandPath fromIO initialPath | otherwise =
  maybe [] f $ Array.head initialPath.io
  where
  f ∷ InsertableCardIOType → Array Path
  f initialIO = Array.concat $ g <$> (cardsThatOutput initialIO)

  g ∷ InsertableCardType → Array Path
  g card = h card `Array.mapMaybe` (inputsFor card)

  h ∷ InsertableCardType → InsertableCardIOType → Maybe Path
  h card io
    | card `Foldable.elem` initialPath.c
        || (Array.length $ Array.filter (eq io) initialPath.io) >= 2
        || card `Foldable.elem` cardsToExcludeFromPaths =
          Nothing
  h card io =
    Just { c: pathCards, io: pathIO, f: pathFinished }
    where
    pathFinished = fromIO `Foldable.elem` pathIO
    pathIO = Array.cons io initialPath.io
    pathCards = Array.cons card initialPath.c

fromMaybePort ∷ Maybe Port → InsertableCardIOType
fromMaybePort input = maybe None fromPort input

printIOType ∷ InsertableCardIOType → String
printIOType = case _ of
  Form → "a form"
  Chart → "a chart"
  GeoChart → "geo chart"
  Data → "data"
  Download → "a download"
  Markdown → "markdown"
  None → "to be the first card in a deck"
  Variables → "variables"
  Terminal → "nothing"


printIOType' ∷ InsertableCardIOType → Maybe String
printIOType' = case _ of
  Form → Just "the form"
  Chart → Just "the chart"
  Data → Just "the data"
  Download → Just "the download"
  Markdown → Just "the markdown"
  Variables → Just "the variables"
  _ → Nothing

eitherOr ∷ Array String → String
eitherOr strings =
  case Array.length strings of
    1 → String.joinWith "" strings
    n →
      "either "
        <> String.joinWith ", " (Array.take (n - 1) strings)
        <> " or "
        <> String.joinWith "" (Array.drop (n - 1) strings)

fromPort ∷ Port → InsertableCardIOType
fromPort = case _ of
  Port.ResourceKey _ → Data
  Port.DownloadOptions _ → Download
  Port.SlamDown _ → Markdown
  Port.ChartInstructions _ → Chart
  Port.PivotTable _ → Chart
  Port.SetupLabeledFormInput _ → Form
  Port.SetupTextLikeFormInput _ → Form
  Port.Variables → Variables
  Port.ValueMetric _ → Chart
  Port.CategoricalMetric _ → Form
  Port.GeoChart _ → GeoChart
  Port.Terminal → Terminal
  _ → None

toCardType ∷ InsertableCardType → Maybe CardType
toCardType = case _ of
  CacheCard → Just CT.cache
  DraftboardCard → Just CT.draftboard
  OpenCard → Just CT.open
  QueryCard → Just CT.aceSql
  SearchCard → Just CT.search
  SetupChartCard → Nothing
  SetupGeoChartCard → Nothing
  SetupFormCard → Nothing
  SetupDownloadCard → Just CT.downloadOptions
  SetupMarkdownCard → Just CT.aceMarkdown
  SetupVariablesCard → Just CT.variables
  ShowDownloadCard → Just CT.download
  ShowVizCard → Just CT.viz
  ShowMarkdownCard → Just CT.markdown
  TableCard → Just CT.table
  TroubleshootCard → Just CT.troubleshoot
  TabsCard → Just CT.tabs
  StructureEditorCard → Just CT.structureEditor

print ∷ InsertableCardType → String
print = case _ of
  SetupChartCard → "Setup Chart"
  SetupFormCard → "Setup Form"
  a → foldMap CT.name $ toCardType a

aAn ∷ String → String
aAn s =
  if String.toLower (String.take 1 s) `Foldable.elem` vowels
    then "An"
    else "A"
  where
  vowels = [ "a", "e", "i", "o", "u" ]

reason ∷ InsertableCardIOType → CardType → String
reason io card = fold
  [ aAn $ CT.name card
  , " "
  , show $ CT.name card
  , " card can't "
  , actual
  , " because it needs "
  , expected
  , action
  , "."
  ]
  where
  ictCardType =
    fromCardType card
  actual = case io of
    None → "be the first card in a deck"
    _ → "follow a card which outputs " <> printIOType io
  expected =
    eitherOr $ map printIOType $ inputsFor ictCardType
  action =
    foldMap (append " to ") $ printAction ictCardType

printAction ∷ InsertableCardType → Maybe String
printAction = case _ of
  CacheCard → Just "cache"
  DraftboardCard → Nothing
  OpenCard → Nothing
  QueryCard → Nothing
  SearchCard → Just "search"
  SetupChartCard → Just "set up a chart for"
  SetupGeoChartCard → Just "set up geo chart for"
  SetupFormCard → Just "set up a form for"
  SetupDownloadCard → Just "setup a download for"
  SetupMarkdownCard → Nothing
  SetupVariablesCard → Nothing
  ShowVizCard → Just "show"
  ShowDownloadCard → Just "show"
  ShowMarkdownCard → Just "show"
  TableCard → Just "tabulate"
  TroubleshootCard → Just "troubleshoot"
  TabsCard → Nothing
  StructureEditorCard → Nothing

fromCardType ∷ CardType → InsertableCardType
fromCardType = case_
  # fromChart
  # fromSimple
  # fromAce
  # fromInput
  # fromSelect
  # fromStatic
  # fromGeo
  where
  fromChart ∷ ∀ r. (Variant r → InsertableCardType) → CT.Chart r → InsertableCardType
  fromChart cb = cb
    # on CT._pie setupChartThunk
    # on CT._bar setupChartThunk
    # on CT._line setupChartThunk
    # on CT._area setupChartThunk
    # on CT._scatter setupChartThunk
    # on CT._radar setupChartThunk
    # on CT._funnel setupChartThunk
    # on CT._graph setupChartThunk
    # on CT._heatmap setupChartThunk
    # on CT._sankey setupChartThunk
    # on CT._gauge setupChartThunk
    # on CT._boxplot setupChartThunk
    # on CT._metric setupChartThunk
    # on CT._pivot setupChartThunk
    # on CT._punchCard setupChartThunk
    # on CT._candlestick setupChartThunk
    # on CT._parallel setupChartThunk
  setupChartThunk _ = SetupChartCard

  fromSimple ∷ ∀ r. (Variant r → InsertableCardType) → CT.Simple r → InsertableCardType
  fromSimple cb = cb
    # on CT._cache (const CacheCard)
    # on CT._draftboard (const DraftboardCard)
    # on CT._open (const OpenCard)
    # on CT._search (const SearchCard)
    # on CT._geo (const ShowVizCard)
    # on CT._downloadOptions (const SetupDownloadCard)
    # on CT._variables (const SetupVariablesCard)
    # on CT._chart (const ShowVizCard)
    # on CT._download (const ShowDownloadCard)
    # on CT._markdown (const ShowMarkdownCard)
    # on CT._table (const TableCard)
    # on CT._troubleshoot (const TroubleshootCard)
    # on CT._form (const ShowVizCard)
    # on CT._tabs (const TabsCard)
    # on CT._structureEditor (const StructureEditorCard)
    # on CT._viz (const ShowVizCard)

  fromAce ∷ ∀ r. (Variant r → InsertableCardType) → CT.Ace r → InsertableCardType
  fromAce cb = cb
    # on CT._aceSql (const QueryCard)
    # on CT._aceMarkdown (const SetupMarkdownCard)

  fromInput ∷ ∀ r. (Variant r → InsertableCardType) → CT.Input r → InsertableCardType
  fromInput cb = cb
    # on CT._text setupFormInputThunk
    # on CT._numeric setupFormInputThunk
    # on CT._date setupFormInputThunk
    # on CT._time setupFormInputThunk
    # on CT._datetime setupFormInputThunk
  fromSelect ∷ ∀ r. (Variant r → InsertableCardType) → CT.Select r → InsertableCardType
  fromSelect cb = cb
    # on CT._dropdown setupFormInputThunk
    # on CT._radio setupFormInputThunk
    # on CT._checkbox setupFormInputThunk
  fromStatic ∷ ∀ r. (Variant r → InsertableCardType) → CT.Static r → InsertableCardType
  fromStatic cb = cb # on CT._static setupFormInputThunk

  setupFormInputThunk _ = SetupFormCard

  fromGeo ∷ ∀ r. (Variant r → InsertableCardType) → CT.Geo r → InsertableCardType
  fromGeo cb = cb
    # on CT._geoMarker setupGeoThunk
    # on CT._geoHeatmap setupGeoThunk
  setupGeoThunk _ = SetupGeoChartCard


all ∷ Array InsertableCardType
all =
  [ OpenCard
  , QueryCard
  , SearchCard
  , TableCard
  , SetupChartCard
  , ShowVizCard
  , SetupFormCard
  , SetupGeoChartCard
  , SetupMarkdownCard
  , ShowMarkdownCard
  , DraftboardCard
  , TabsCard
  , SetupDownloadCard
  , ShowDownloadCard
  , CacheCard
  , SetupVariablesCard
  , TroubleshootCard
  , StructureEditorCard
  ]
