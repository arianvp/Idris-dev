{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}

module ProofShell where

import Typecheck
import Evaluate
import Core
import ProofState
import ShellParser

import Control.Monad.State
import System.Console.Readline

data ShellState = State { ctxt    :: Context,
                          prf     :: Maybe ProofState,
                          exitNow :: Bool
                        }

initState c = State c Nothing False

processCommand :: Command -> ShellState -> (ShellState, String)
processCommand (Theorem n ty) state 
    = case check (ctxt state) [] ty of
              OK (gl, Set _) -> (state { prf = Just (newProof n (ctxt state) gl) }, "")
              OK _ ->           (state, "Goal is not a type")
              err ->            (state, show err)
processCommand Quit state = (state { exitNow = True }, "Bye bye")
processCommand (Tac t) state 
    | Just ps <- prf state = case processTactic t ps of
                                OK (ps', resp) -> (state { prf = Just ps' }, resp)
                                err -> (state, show err)
    | otherwise = (state, "No proof in progress")

runShell :: ShellState -> IO ShellState
runShell st = do (prompt, parser) <- 
                           maybe (return ("> ", parseCommand)) 
                                 (\st -> do print st
                                            return (show (thname st) ++ "> ", parseTactic)) 
                                 (prf st)
                 x <- readline prompt
                 cmd <- case x of
                    Nothing -> return $ Right Quit
                    Just input -> do addHistory input
                                     return (parser input)
                 case cmd of
                    Left err -> do putStrLn (show err)
                                   runShell st
                    Right cmd -> do let (st', r) = processCommand cmd st
                                    putStrLn r
                                    if (not (exitNow st')) then runShell st'
                                                           else return st'

