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

module SlamData.Workspace.Card.Cache.Error where

import SlamData.Prelude

import Quasar.Advanced.QuasarAF (QError, printQError)
import Quasar.Types (FilePath)
import SlamData.GlobalError as GE
import Utils (hush)

data CacheError
  = CacheInvalidFilepath String
  | CacheQuasarError QError
  | CacheErrorSavingFile
  | CacheResourceNotModified FilePath

instance showCacheError ∷ Show CacheError where
  show = case _ of
    CacheInvalidFilepath fp → "(CacheInvalidFilepath " <> show fp <> ")"
    CacheQuasarError qErr → "(CacheQuasarError " <> printQError qErr <> ")"
    CacheErrorSavingFile → "CacheErrorSavingFile"
    CacheResourceNotModified fp → "(CacheResourceNotModified " <> show fp <> ")"

cacheToGlobalError ∷ CacheError → Maybe GE.GlobalError
cacheToGlobalError = case _ of
  CacheQuasarError qErr → hush (GE.fromQError qErr)
  _ → Nothing
