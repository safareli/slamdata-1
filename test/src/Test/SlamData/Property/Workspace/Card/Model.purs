{-
Copyright 2015 SlamData, Inc.

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

module Test.SlamData.Property.Workspace.Card.Model
  ( ArbCard
  , runArbCard
  , check
  , checkCardEquality
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Foldable (mconcat)

import SlamData.Workspace.Card.Model (Model, encode, decode)

import Test.StrongCheck (QC, Result(..), class Arbitrary, arbitrary, quickCheck, (<?>))

import Test.Property.ArbJson (runArbJson)
import Test.SlamData.Property.Workspace.Card.CardId (runArbCardId)
import Test.SlamData.Property.Workspace.Card.CardType (runArbCardType)

newtype ArbCard = ArbCard Model

runArbCard :: ArbCard -> Model
runArbCard (ArbCard m) = m

instance arbitraryArbCard :: Arbitrary ArbCard where
  arbitrary = do
    cardId <- runArbCardId <$> arbitrary
    cardType <- runArbCardType <$> arbitrary
    inner <- runArbJson <$> arbitrary
    hasRun <- arbitrary
    pure $ ArbCard { cardId, cardType, inner, hasRun }

check :: QC Unit
check = quickCheck $ runArbCard >>> \model ->
  case decode (encode model) of
    Left err -> Failed $ "Decode failed: " ++ err
    Right model' -> checkCardEquality model model'

checkCardEquality :: Model -> Model -> Result
checkCardEquality model model' =
  mconcat
   [ model.cardId == model'.cardId <?> "cardId mismatch"
   , model.cardType == model'.cardType <?> "cardType mismatch"
   , model.inner == model'.inner <?> "inner mismatch"
   , model.hasRun == model'.hasRun <?> "hasRun mismatch"
   ]
