{-
Copyright 2017 SlamData, Inc.

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

module SlamData.Workspace.Card.Setups.Dimension where

import SlamData.Prelude

import Data.Argonaut as J
import Data.Argonaut ((~>), (:=), (.?))
import Data.Array as Array
import Data.Codec as C
import Data.Codec.Argonaut as CA
import Data.Lens (Lens', lens, Traversal', wander, _Just)
import Data.Newtype (un)
import Data.String as String
import Data.Traversable (sequenceDefault)

import SlamData.Workspace.Card.Setups.Transform (Transform(..))
import SlamData.Workspace.Card.Setups.Transform.Aggregation as Ag

import Test.StrongCheck.Arbitrary (class Arbitrary, arbitrary)
import Test.StrongCheck.Gen as Gen
import Test.StrongCheck.Data.Argonaut (ArbJCursor(..))

type JCursorDimension = Dimension J.JCursor J.JCursor
type LabeledJCursor = Dimension Void J.JCursor

data Dimension a b
  = Dimension (Maybe (Category a)) (Category b)

data Category p
  = Static String
  | Projection (Maybe Transform) p

topDimension ∷ LabeledJCursor
topDimension = Dimension Nothing $ Projection Nothing J.JCursorTop

projection ∷ ∀ a b. b → Dimension a b
projection = Dimension Nothing <<< Projection Nothing

projectionWithCategory ∷ ∀ a b. Category a → b → Dimension a b
projectionWithCategory c = Dimension (Just c) <<< Projection Nothing

projectionWithAggregation ∷ ∀ a b. Maybe Ag.Aggregation → b → Dimension a b
projectionWithAggregation t = Dimension Nothing <<< Projection (Aggregation <$> t)

_value ∷ ∀ a b. Lens' (Dimension a b) (Category b)
_value = lens
  (\(Dimension _ b) → b)
  (\(Dimension a _) b → Dimension a b)

_category ∷ ∀ a b. Lens' (Dimension a b) (Maybe (Category a))
_category = lens
  (\(Dimension a _) → a)
  (\(Dimension _ b) a → Dimension a b)

_transform ∷ ∀ p. Traversal' (Category p) (Maybe Transform)
_transform = wander \f → case _ of
  Projection t p → flip Projection p <$> f t
  c → pure c

_projection ∷ ∀ p. Traversal' (Category p) p
_projection = wander \f → case _ of
  Projection t p → Projection t <$> f p
  c → pure c

_Static ∷ ∀ p. Traversal' (Category p) String
_Static = wander \f → case _ of
  Static s → map Static $ f s
  c → pure c

_staticCategory ∷ ∀ a b. Traversal' (Dimension a b) String
_staticCategory = _category ∘ _Just ∘ _Static

printCategory ∷ ∀ p. (p → String) → Category p → String
printCategory f = case _ of
  Static str → str
  Projection _ p → f p

isStatic ∷ ∀ p. Category p → Boolean
isStatic = case _ of
  Static _ → true
  _ → false

jcursorLabel ∷ LabeledJCursor → String
jcursorLabel = case _ of
  Dimension (Just (Static label)) _ | label ≠ "" → label
  Dimension _ (Static label) → label
  Dimension _ (Projection _ jcursor) → prettyPrintJCursor jcursor

derive instance eqDimension ∷ (Eq a, Eq b) ⇒ Eq (Dimension a b)
derive instance eqCategory ∷ Eq p ⇒ Eq (Category p)

derive instance ordDimension ∷ (Ord a, Ord b) ⇒ Ord (Dimension a b)
derive instance ordCategory ∷ Ord p ⇒ Ord (Category p)

derive instance functorDimension ∷ Functor (Dimension a)
derive instance functorCategory ∷ Functor Category

instance applyCategory ∷ Apply Category where
  apply (Static s) _ = Static s
  apply _ (Static s) = Static s
  apply (Projection a f) (Projection b v) = Projection (a <|> b) $ f v

instance applicativeCategory ∷ Applicative Category where
  pure s = Projection Nothing s

instance applyDimension ∷ Apply (Dimension a) where
  apply (Dimension a f) (Dimension b v) =
    Dimension (a <|> b) $ apply f v

instance applicativeDimension ∷ Applicative (Dimension a) where
  pure a = Dimension Nothing $ pure a

instance bifunctorDimension ∷ Bifunctor Dimension where
  bimap f g (Dimension a b) = Dimension (map f <$> a) (g <$> b)

instance foldableCategory ∷ Foldable Category where
  foldMap f = case _ of
    Static _ → mempty
    Projection _ v → f v
  foldl f acc = case _ of
    Static _ → acc
    Projection _ v → f acc v
  foldr f acc = case _ of
    Static _ → acc
    Projection _ v → f v acc

instance traversableCategory ∷ Traversable Category where
  traverse f = case _ of
    Static s → pure $ Static s
    Projection t v → Projection t <$> f v
  sequence = sequenceDefault

instance foldableDimension ∷ Foldable (Dimension a) where
  foldMap f (Dimension _ pr) = foldMap f pr
  foldl f acc (Dimension _ pr) = foldl f acc pr
  foldr f acc (Dimension _ pr) = foldr f acc pr

instance traversableDimension ∷ Traversable (Dimension a) where
  traverse f (Dimension a pr) = Dimension a <$> traverse f pr
  sequence = sequenceDefault

instance
  encodeJsonDimension
  ∷ ( J.EncodeJson a, J.EncodeJson b )
  ⇒ J.EncodeJson (Dimension a b)
  where
    encodeJson (Dimension category value) =
      "value" := value
      ~> "category" := category
      ~> J.jsonEmptyObject

instance encodeJsonCategory ∷ J.EncodeJson p ⇒ J.EncodeJson (Category p) where
  encodeJson = case _ of
    Static value →
      "type" := "static"
      ~> "value" := value
      ~> J.jsonEmptyObject
    Projection transform value →
      "type" := "projection"
      ~> "value" := value
      ~> "transform" := transform
      ~> J.jsonEmptyObject

instance
  decodeJsonDimension
  ∷ ( J.DecodeJson a, J.DecodeJson b )
    ⇒ J.DecodeJson (Dimension a b) where
  decodeJson json = do
    obj ← J.decodeJson json
    Dimension
      <$> obj .? "category"
      <*> obj .? "value"

instance decodeJsonCategory ∷ J.DecodeJson p ⇒ J.DecodeJson (Category p) where
  decodeJson json = do
    obj ← J.decodeJson json
    obj .? "type" >>= case _ of
      "static" →
        Static
          <$> obj .? "value"
      "projection" →
        Projection
          <$> obj .? "transform"
          <*> obj .? "value"
      ty →
        throwError
          $ "Invalid category type: " <> ty

instance arbitraryDimension ∷ (Arbitrary a, Arbitrary b) ⇒ Arbitrary (Dimension a b) where
  arbitrary = Dimension <$> arbitrary <*> arbitrary

instance arbitraryCategory ∷ Arbitrary p ⇒ Arbitrary (Category p) where
  arbitrary = Gen.chooseInt 1 2 >>= case _ of
    1 → Static <$> arbitrary
    _ → Projection <$> arbitrary <*> arbitrary

newtype DimensionWithStaticCategory a = DimensionWithStaticCategory (Dimension Void a)

newtype StaticCategory = StaticCategory (Category Void)

derive instance functorDimensionWithStaticCategory ∷ Functor DimensionWithStaticCategory
derive instance newtypeDimensionWithStaticCategory ∷ Newtype (DimensionWithStaticCategory a) _
derive instance newtypeStaticCategory ∷ Newtype StaticCategory _

instance arbitraryDimensionWithStaticCategory ∷ Arbitrary a ⇒ Arbitrary (DimensionWithStaticCategory a) where
  arbitrary = DimensionWithStaticCategory
    <$> (Dimension <$> (map (un StaticCategory) <$> arbitrary) <*> arbitrary)

instance arbitraryStaticCategory ∷ Arbitrary StaticCategory where
  arbitrary = StaticCategory ∘ Static <$> arbitrary

genLabeledJCursor ∷ Gen.Gen LabeledJCursor
genLabeledJCursor = map (map (un ArbJCursor) ∘ un DimensionWithStaticCategory) arbitrary

codecLabeledJCursor ∷ CA.JsonCodec LabeledJCursor
codecLabeledJCursor =
  C.basicCodec
    (lmap CA.TypeMismatch ∘ J.decodeJson)
    J.encodeJson

prettyPrintJCursor ∷ J.JCursor → String
prettyPrintJCursor = go ""
  where
  go "" (J.JField f n) = go f n
  go "" (J.JIndex i n) = go (show i) n
  go "" J.JCursorTop = "value"
  go s (J.JField f n) = go (s <> "." <> f) n
  go s (J.JIndex i n) = go (s <> "[" <> show i <> "]") n
  go s J.JCursorTop = s

defaultJCursorCategory ∷ ∀ a. J.JCursor → Category a
defaultJCursorCategory =
  Static ∘ String.joinWith "_" ∘ go [] ∘ J.insideOut
  where
  go label (J.JField field _) = Array.cons field label
  go label (J.JIndex ix next) = go (Array.cons (show ix) label) next
  go label _ = Array.cons "value" label

defaultJCursorDimension ∷ J.JCursor → LabeledJCursor
defaultJCursorDimension jc =
  projectionWithCategory (defaultJCursorCategory jc) jc

pairToDimension ∷ J.JCursor → Ag.Aggregation → LabeledJCursor
pairToDimension v a =
  pairWithMaybeAggregation v $ Just a

pairWithMaybeAggregation ∷ J.JCursor → Maybe Ag.Aggregation → LabeledJCursor
pairWithMaybeAggregation v a =
  Dimension (Just $ defaultJCursorCategory v) (Projection (map Aggregation a) v)
