module FixSpec where

import Prelude hiding (append)

import Control.Monad.Cleanup (runCleanupT)
import Control.Monad.IOSync.Class (liftIOSync)
import Data.IORef (newIORef)
import Data.Tuple (Tuple(..))
import Specular.FRP (Dynamic, Event, WeakDynamic, holdDyn, never, newEvent, subscribeEvent_, weaken)
import Specular.FRP.Base (mergeEvents)
import Specular.FRP.Fix (fixDyn, fixEvent, fixFRP)
import Specular.FRP.WeakDynamic (subscribeWeakDyn_)
import Test.Spec (Spec, describe, it, pending')
import Test.Spec.Runner (RunnerEffects)
import Test.Utils (append, ioSync, shouldHaveInferredType, shouldHaveValue)
import Type.Prelude (Proxy(..))

spec :: forall eff. Spec (RunnerEffects eff) Unit
spec = do
  describe "fixEvent" $ do
    it "connects result Event to input Event" $ do
     log <- ioSync $ newIORef []
     Tuple fire _ <- ioSync $ runCleanupT $
       fixEvent $ \input -> do
         _ <- subscribeEvent_ (append log) input

         {event: output, fire} <- liftIOSync newEvent
         pure (Tuple output fire)

     ioSync $ fire 1

     log `shouldHaveValue` [1]

    pending' "input and output occur simultaneously" $ do
     log <- ioSync $ newIORef []
     Tuple fire _ <- ioSync $ runCleanupT $
       fixEvent $ \input -> do
         {event: output, fire} <- liftIOSync newEvent
         _ <- subscribeEvent_ (append log) $
           mergeEvents
             (\_ -> pure "input") (\_ -> pure "output") (\_ _ -> pure "both")
             input output
         pure (Tuple output fire)

     ioSync $ fire unit

     -- TODO: the result of this test is doubly wrong:
     -- The "wrong" result is ["output", "input"],
     -- but the implementation currently gives ["output", "both"]
     log `shouldHaveValue` ["both"]

  describe "fixDyn" $ do
   it "gives input WeakDynamic initial value" $ do
     log <- ioSync $ newIORef []
     Tuple _ _ <- ioSync $ runCleanupT $
       fixDyn $ \input -> do
         _ <- subscribeWeakDyn_ (append log) input

         output <- holdDyn 1 never
         pure (Tuple output unit)

     log `shouldHaveValue` [1]

   it "propagates output changes to input" $ do
     {event,fire} <- ioSync newEvent
     log <- ioSync $ newIORef []
     Tuple _ _ <- ioSync $ runCleanupT $
       fixDyn $ \input -> do
         _ <- subscribeWeakDyn_ (append log) input

         output <- holdDyn 1 event
         pure (Tuple output unit)

     ioSync $ fire 2

     log `shouldHaveValue` [1, 2]

   pending' "input and output change simultaneously" $ do
     {event,fire} <- ioSync newEvent
     log <- ioSync $ newIORef []
     Tuple _ _ <- ioSync $ runCleanupT $
       fixDyn $ \input -> do
         output <- holdDyn 1 event
         _ <- subscribeWeakDyn_ (append log) $ Tuple <$> input <*> weaken output
         pure (Tuple output unit)

     ioSync $ fire 2

     log `shouldHaveValue` [Tuple 1 1, Tuple 2 2]

  describe "fixRecord" $ do
    describe "type inference" $ do
      it "empty record" $ do
        void $ ioSync $ runCleanupT $
          fixFRP $ \r -> do
            let _ = r `shouldHaveInferredType` (Proxy :: Proxy {})
            pure (Tuple {} unit)

      it "non-empty record" $ do
        void $ ioSync $ runCleanupT $
          fixFRP $ \r -> do
            let _ = r `shouldHaveInferredType`
                      (Proxy :: Proxy { event :: Event Int
                                      , dynamic :: WeakDynamic Int
                                      })
            pure (Tuple { event: never :: Event Int
                        , dynamic: pure 0 :: Dynamic Int
                        }
                        unit)

    it "works for Events and Dynamics" $ do
      log <- ioSync $ newIORef []
      Tuple fire _ <- ioSync $ runCleanupT $
        fixFRP $ \input -> do
          {event, fire} <- liftIOSync newEvent
          dynamic <- holdDyn 0 event

          _ <- subscribeEvent_ (append log) input.event
          _ <- subscribeWeakDyn_ (append log) input.dynamic
          pure (Tuple { event, dynamic } fire)

      ioSync $ fire 1

      log `shouldHaveValue` [0, 1, 1]
