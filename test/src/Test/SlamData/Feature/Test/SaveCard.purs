module Test.SlamData.Feature.Test.SaveCard where

import SlamData.Prelude

import Data.String as Str

import Test.Feature.Log (successMsg)
import Test.Feature.Scenario (scenario)
import Test.SlamData.Feature.Expectations as Expect
import Test.SlamData.Feature.Interactions as Interact
import Test.SlamData.Feature.Monad (SlamFeature)


saveCardScenario ∷ String → Array String → SlamFeature Unit → SlamFeature Unit
saveCardScenario =
  scenario
    "Saving/caching data source card output"
    (Interact.createNotebookInTestFolder "Save card")
    (Interact.deleteFileInTestFolder "Save card.slam"
     ≫ Interact.deleteFileInTestFolder "zoo")

import Selenium.Monad (later)

test ∷ SlamFeature Unit
test =
  saveCardScenario "Save cell output to file" [] do
    Interact.insertQueryCardAsFirstCardInNewStack
    Interact.provideQueryInLastQueryCard
      "SELECT measureOne, measureTwo from `/test-mount/testDb/flatViz`"
    Interact.insertSaveCardAsNextAction
    Interact.provideSaveDestinationInLastSaveCard
      "/test-mount/testDb/zoo"
    Interact.doSaveInLastSaveCard
    Interact.insertJTableCardAsNextAction
    Interact.browseTestFolder
    Interact.accessFile "zoo"
    Interact.insertJTableCardAsNextAction
    Expect.tableColumnsAre ["measureOne", "measureTwo"]
    successMsg "Successfully saved data source card output to file"
