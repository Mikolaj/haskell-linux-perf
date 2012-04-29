-----------------------------------------------------------------------------
-- |
-- Copyright   : (c) 2010,2011,2012 Simon Marlow, Bernie Pope
-- License     : BSD-style
-- Maintainer  : florbitous@gmail.com
-- Stability   : experimental
-- Portability : ghc
--
-----------------------------------------------------------------------------

import GHC.RTS.Events hiding (pid)
import Data.Word

-- import Profiling.Linux.Perf (PerfFileContents, readPerfData)
import Profiling.Linux.Perf (PerfEvent (..), perfTrace, PerfEventTypeMap)
import System.Exit (exitWith, ExitCode (ExitFailure))
import System.IO (hPutStrLn, stderr)
import System.Environment (getArgs)
import Data.Word (Word32)
import Data.Map (toList)

die :: String -> IO a
die s = hPutStrLn stderr s >> exitWith (ExitFailure 1)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [pid, inF, outF] -> do
       (perfEventTypeMap, perfEvents) <- perfTrace inF
       let perfEventlog = perfToEventlog (read pid) perfEventTypeMap perfEvents
       writeEventLogToFile outF perfEventlog
    _ -> die "Syntax: to-eventlog [--no-files|perf_file eventlog_file]"
{-
      perfData <- readPerfData inF
      let perfEventlog = perfToEventlog perfData
      writeEventLogToFile outF perfEventlog
-}

type PID = Word32

perfToEventlog :: PID -> PerfEventTypeMap -> [PerfEvent] -> EventLog
perfToEventlog pid typeMap events =
   eventLog (typeMapToEvents typeMap ++ 
             map perfToGHC (filter (eventPID pid) events))

eventPID :: PID -> PerfEvent -> Bool
eventPID pidTarget event = pidTarget == pid event

typeMapToEvents :: PerfEventTypeMap -> [Event]
typeMapToEvents typeMap = map toPerfName $ toList typeMap
   where
   toPerfName :: (Word64, String) -> Event
   toPerfName (identity, eventName) =
      Event 0 $ PerfName { perfNum = fromIntegral identity, name = eventName }

perfToGHC :: PerfEvent -> Event
perfToGHC e@(PerfSample {}) =
   Event (timestamp e) (PerfTracepoint { perfNum = fromIntegral $ identity e, thread = tid e })

test :: EventLog
test = eventLog $
  [ Event 0 (PerfName 0 "L2 cache misses")
  , Event 1000 (PerfCounter 0 1)
  , Event 1100 (PerfCounter 0 2)
  , Event 2000 (PerfName 1 "kill")
  , Event 2100 (PerfCounter 0 3)
  , Event 2200 (PerfTracepoint 1 0)
  ]

eventLog :: [Event] -> EventLog
eventLog events = EventLog (Header testEventTypes) (Data events)

perfName :: Word16
perfName = 140

perfCounter :: Word16
perfCounter = 141

perfTracepoint :: Word16
perfTracepoint = 142

testEventTypes :: [EventType]
testEventTypes =
  [ EventType perfName "perf event name" Nothing
  , EventType perfCounter "perf event counter" (Just $ sz_perf_num + 8)
  , EventType perfTracepoint "perf event tracepoint"
      (Just $ sz_perf_num + sz_tid)
  ]

type EventTypeSize = Word16

sz_perf_num :: EventTypeSize
sz_perf_num = 4

sz_tid :: EventTypeSize
sz_tid  = 4
