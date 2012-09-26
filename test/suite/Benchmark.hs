{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

------------------------------------------------------------------------------
import           Blaze.ByteString.Builder
import           Criterion
import           Criterion.Main
import           Criterion.Measurement hiding (getTime)
import           Control.Concurrent
import           Control.Error
import           Control.Exception (evaluate)
import           Control.Monad
import qualified Data.ByteString as B
import qualified Data.Text as T
import           Data.Text.Encoding
import           Data.Time.Clock
import           Data.Maybe
import           System.Environment

import Heist
import qualified Heist.Compiled as C
import qualified Heist.Interpreted as I
import Heist.TestCommon

loadWithCache baseDir = do
    etm <- runEitherT $ do
        templates <- loadTemplates baseDir
        let hc = HeistConfig [] defaultLoadTimeSplices [] [] templates
        initHeistWithCacheTag hc
    either (error . unlines) (return . fst) etm

main = do
    let page = "faq"
        pageStr = T.unpack $ decodeUtf8 page
        dir = "snap-website"
    hs <- loadWithCache dir
    let !compiledTemplate = fst $! fromJust $! C.renderTemplate hs page
        compiledAction = do
            res <- compiledTemplate
            return $! toByteString $! res
    out <- compiledAction
    B.writeFile (pageStr++".out.compiled."++dir) $ out
    putStrLn "Templates loaded"
    replicateM_ 10000 $ whnfIO compiledAction
    putStrLn "done"

justRender dir = do
    let page = "faq"
        pageStr = T.unpack $ decodeUtf8 page
    hs <- loadWithCache dir
    let !compiledTemplate = fst $! fromJust $! C.renderTemplate hs page
        compiledAction = do
            res <- compiledTemplate
            return $! toByteString $! res
    out <- compiledAction
    B.writeFile (pageStr++".out.compiled."++dir) $ out

    defaultMain
       [ bench (pageStr++"-compiled (just render)") (whnfIO compiledAction)
       ]

------------------------------------------------------------------------------
--applyComparison :: IO ()
applyComparison dir = do
    let page = "faq"
        pageStr = T.unpack $ decodeUtf8 page
    hs <- loadWithCache dir
    let compiledAction = do
            res <- fst $ fromJust $ C.renderTemplate hs page
            return $! toByteString $! res
    out <- compiledAction
    B.writeFile (pageStr++".out.compiled."++dir) $ out

    let interpretedAction = do
            res <- I.renderTemplate hs page
            return $! toByteString $! fst $! fromJust res
    out2 <- interpretedAction
    B.writeFile (pageStr++".out.interpreted."++dir) $ out

    defaultMain
       [ bench (pageStr++"-compiled") (whnfIO compiledAction)
       , bench (pageStr++"-interpreted") (whnfIO interpretedAction)
       , bench "getCurrentTime"         (whnfIO getCurrentTime)
       ]

cmdLineTemplate :: String -> String -> IO ()
cmdLineTemplate dir page = do
--    args <- getArgs
--    let page = head args
--    let dir = "test/snap-website"
    hs <- loadHS dir
    let action = fst $ fromJust $ C.renderTemplate hs
            (encodeUtf8 $ T.pack page)
    out <- action
    B.writeFile (page++".out.cur") $ toByteString out

--    reference <- B.readFile "faq.out"
--    if False
--      then do
--        putStrLn "Template didn't render properly"
--        error "Aborting"
--      else
--        putStrLn "Template rendered correctly"

    defaultMain [
         bench (page++"-speed") action
       ]
