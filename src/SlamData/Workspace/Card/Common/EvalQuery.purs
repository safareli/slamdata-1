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

module SlamData.Workspace.Card.Common.EvalQuery
  ( CardEvalQuery(..)
  , CardSetupInfo
  , liftWithCanceler
  , liftWithCanceler'
  , liftWithCancelerP
  , liftWithCancelerP'
  , module SlamData.Workspace.Card.Eval.CardEvalT
  ) where

import SlamData.Prelude

import Control.Monad.Aff (Canceler)

import Data.Argonaut (Json)

import Halogen (ParentDSL, ComponentDSL)
import Halogen.Component.Utils as Hu

import SlamData.Effects (Slam, SlamDataEffects)
import SlamData.Workspace.Card.CardId as CID
import SlamData.Workspace.Card.Eval.CardEvalT (CardEvalInput, CardEvalResult, CardEvalT, runCardEvalT, temporaryOutputResource)
import SlamData.Workspace.Card.Port as Port

import Utils.Path (DirPath)

-- | The query algebra shared by the inner parts of a card component.
-- |
-- | - `EvalCard` is a command sent from the deck that runs the card. An
-- |   optional input value (the output from another card) is provided, and a
-- |   continuation for the evaluation result to be returned to.
-- | - `SetupCard` is will be called when the card is being added as a linked
-- |   card from another, passing through the current input port value so the
-- |   current card can set its state based on that. Used to pull a VarMap
-- |   through for autocomplete purposes, or for the search card to be able to
-- |   auto-select the parent card's result set as the resource, etc.
-- | - `NotifyRunCard` allows the card to notify the deck that it should be
-- |   run - the card cannot run itself directly.
data CardEvalQuery a
  = EvalCard CardEvalInput (CardEvalResult → a)
  | SetupCard CardSetupInfo a
  | NotifyRunCard a
  | NotifyStopCard a
  | SetCanceler (Canceler SlamDataEffects) a
  | Save (Json → a)
  | Load Json a
  | SetDimensions { width ∷ Number, height ∷ Number } a

type CardSetupInfo =
  { path ∷ Maybe DirPath
  , input ∷ Port.Port
  , cardId ∷ CID.CardId
  }

liftWithCancelerP
  ∷ ∀ a state slot innerQuery innerState
  . Slam a
  → ParentDSL
      state innerState
      CardEvalQuery innerQuery
      Slam slot a
liftWithCancelerP =
  Hu.liftWithCanceler' SetCanceler

liftWithCancelerP'
  ∷ ∀ a state innerState innerQuery query slot
  . Slam a
  → ParentDSL
      state innerState
      (Coproduct CardEvalQuery query) innerQuery
      Slam slot a
liftWithCancelerP' =
  Hu.liftWithCanceler' (\c u → left $ SetCanceler c u)

liftWithCanceler
  ∷ ∀ a state
  . Slam a
  → ComponentDSL state CardEvalQuery Slam a
liftWithCanceler =
  Hu.liftWithCanceler SetCanceler

liftWithCanceler'
  ∷ ∀ state query a
  . Slam a
  → ComponentDSL state (Coproduct CardEvalQuery query) Slam a
liftWithCanceler' =
  Hu.liftWithCanceler (\c u → left $ SetCanceler c u)
