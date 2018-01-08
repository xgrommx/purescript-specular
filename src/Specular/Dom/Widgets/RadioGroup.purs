module Specular.Dom.Widgets.RadioGroup
  ( radioGroup
  ) where

import Prelude

import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Random (random)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.TraversableWithIndex (forWithIndex)
import Data.Tuple (Tuple(..), fst, snd)
import Partial.Unsafe (unsafePartial)
import Specular.Dom.Node.Class ((:=))
import Specular.Dom.Widget (class MonadWidget)
import Specular.Dom.Widgets.Input (BooleanInputType(Radio), booleanInputView)
import Specular.FRP (Dynamic, Event, fixFRP, holdDyn, leftmost)
import Specular.FRP.Base (filterMapEvent, hostEffect)

type RadioGroupConfig m a =
  { options :: Array a
      -- ^ Possible selections
  , initialValueIndex :: Int
      -- ^ Index of initial value in `options`.
      -- Must be in bounds, else `radioGroup` will crash
  , render :: forall b. String -> a -> m b -> m b
      -- ^ Render an option. Takes the radio input ID, the value and the radio input.
      -- Must return the return value of the checkbox, as evidenced by the type.
      --
      -- The radio input ID is intended to be passed to the `for` attribute of
      -- `<label>`. If you do that, click events on label cause the radio to be selected.
  }

radioGroup :: forall m a. MonadWidget m
  => RadioGroupConfig m a
  -> m (Dynamic a)
radioGroup config = fixFRP $ \selectedIndex -> do
  let randomIdentifier = hostEffect $ liftEff $ map (\n -> "radio" <> show n) random
  name <- randomIdentifier
    -- ^ FIXME: document this sorcery

  (changeEvents :: Array (Event (Tuple Int a))) <-
    forWithIndex config.options $ \index option -> do
      id <- randomIdentifier
      let
        isSelected = map (_ == index) selectedIndex
        radio =
          map (filterMapEvent (\b -> if b then Just (Tuple index option)
                                          else Nothing)) $
          booleanInputView Radio isSelected (pure ("name" := name <> "id" := id))
      config.render id option radio

  let
    initialValue = unsafePartial (Array.unsafeIndex config.options config.initialValueIndex)
    valueChanged = leftmost changeEvents

  (value :: Dynamic (Tuple Int a)) <-
    holdDyn (Tuple config.initialValueIndex initialValue) valueChanged
  pure $ Tuple (map fst value) (map snd value)
