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

module SlamData.FileSystem.Dialog where

import SlamData.Prelude

import Data.String as Str
import Halogen.HTML as HH
import Halogen.Component.Proxy as Proxy
import SlamData.Dialog.Component as Dialog
import SlamData.Dialog.Message.Component as Message
import SlamData.FileSystem.Resource as R
import SlamData.FileSystem.Dialog.Share.Component as Share
import SlamData.Render.ClassName as CN

data Definition
  = Delete R.Resource
  | Share String String

data Action = DoDelete R.Resource

dialog ∷ Definition → Dialog.DialogSpec Action
dialog = case _ of
  Delete res →
    Message.mkSpec
      { title: "Confirm deletion"
      , message:
        HH.div_
          [ HH.text "Are you sure you want delete "
          , HH.code_ [ HH.text (R.resourceName res) ]
          , HH.text " ?"
          ]
      , class_: HH.ClassName "sd-delete-dialog"
      , action: Right ("Delete" × DoDelete res)
      }
  Share name url →
    { title: "Share " <> fromMaybe name (Str.stripSuffix (Str.Pattern ".slam") name)
    , class_: HH.ClassName "sd-share-dialog"
    , dialog: Proxy.proxy (Share.component url)
    , buttons:
        pure
          { label: "Dismiss"
          , action: Dialog.Dismiss
          , class_: CN.btnDefault
          , disabled: false
          }
    }
