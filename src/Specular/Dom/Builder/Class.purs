module Specular.Dom.Builder.Class where

import Prelude

import Control.Monad.Cleanup (onCleanup)
import Control.Monad.IOSync (IOSync)
import Control.Monad.Reader (ReaderT(..), runReaderT)
import Control.Monad.Replace (class MonadReplace)
import Control.Monad.Trans.Class (lift)
import Data.Monoid (mempty)
import Data.Tuple (Tuple, snd)
import Specular.Dom.Node.Class (class EventDOM, Attrs, EventType, addEventListener)
import Specular.FRP (class MonadHost, Event, WeakDynamic, hostEffect, newEvent, weakDynamic_)

class Monad m <= MonadDomBuilder node m | m -> node where
  text :: String -> m Unit
  dynText :: WeakDynamic String -> m Unit
  elDynAttr' :: forall a . String -> WeakDynamic Attrs -> m a -> m (Tuple node a)
  rawHtml :: String -> m Unit

elDynAttr ::
     forall node m a
   . MonadDomBuilder node m
  => String
  -> WeakDynamic Attrs
  -> m a
  -> m a
elDynAttr tagName dynAttrs inner = snd <$> elDynAttr' tagName dynAttrs inner


elAttr' ::
     forall node m a
   . MonadDomBuilder node m
  => String
  -> Attrs
  -> m a
  -> m (Tuple node a)
elAttr' tagName attrs inner = elDynAttr' tagName (pure attrs) inner


elAttr ::
     forall node m a
   . MonadDomBuilder node m
  => String
  -> Attrs
  -> m a
  -> m a
elAttr tagName attrs inner = snd <$> elAttr' tagName attrs inner


el' ::
     forall node m a
   . MonadDomBuilder node m
  => String
  -> m a
  -> m (Tuple node a)
el' tagName inner = elAttr' tagName mempty inner


el ::
     forall node m a
   . MonadDomBuilder node m
  => String
  -> m a
  -> m a
el tagName inner = snd <$> el' tagName inner


dynRawHtml ::
     forall node m
   . MonadDomBuilder node m
  => MonadReplace m
  => MonadHost IOSync m
  => WeakDynamic String
  -> m Unit
dynRawHtml dynHtml = weakDynamic_ (rawHtml <$> dynHtml)


domEventWithSample ::
     forall event node m a
   . EventDOM event node
  => MonadHost IOSync m
  => (event -> IOSync a)
  -> EventType
  -> node
  -> m (Event a)
domEventWithSample sample eventType node = do
  {event,fire} <- newEvent
  unsub <- hostEffect $ addEventListener eventType (sample >=> fire) node
  onCleanup unsub
  pure event


domEvent ::
     forall event node m
   . EventDOM event node
  => MonadHost IOSync m
  => EventType
  -> node
  -> m (Event Unit)
domEvent = domEventWithSample (\_ -> pure unit)

instance monadDomBuilderReaderT :: MonadDomBuilder node m => MonadDomBuilder node (ReaderT r m) where
  text = lift <<< text
  dynText = lift <<< dynText
  elDynAttr' tag attrs body = ReaderT $ \env -> elDynAttr' tag attrs $ runReaderT body env
  rawHtml = lift <<< rawHtml

class MonadDetach m where
  -- | Initialize a widget without displaying it immediately.
  -- | Returns the `value` and a monadic action (`widget`) to display the widget.
  -- |
  -- | When the `widget` computation is executed twice, the widget should only
  -- | appear in the latest place it is displayed.
  detach :: forall a. m a -> m { value :: a, widget :: m Unit }

instance monadDetachReaderT :: (Monad m, MonadDetach m) => MonadDetach (ReaderT r m) where
  detach inner = ReaderT $ \env -> do
    { value, widget } <- detach $ runReaderT inner env
    pure { value, widget: lift widget }
