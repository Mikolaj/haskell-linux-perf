-----------------------------------------------------------------------------
-- |
-- Copyright   : (c) 2010,2011,2012 Simon Marlow, Bernie Pope
-- License     : BSD-style
-- Maintainer  : florbitous@gmail.com
-- Stability   : experimental
-- Portability : ghc
--
-- Types for representing the parsed contents of a "perf.data" file
-- "perf.data" is the the output of the "perf record" command on
-- linux (linux performance counter information).
--
-----------------------------------------------------------------------------

module Profiling.Linux.Perf.Types
   ( Event (..)
   , EventType (..)
   , EventCPUMode (..)
   , FileSection (..)
   , FileHeader (..)
   , EventAttr (..)
   , FileAttr (..)
   , EventHeader (..)
   , EventPayload (..)
   , SampleFormat (..)
   , TraceEventType (..)
   , EventAttrFlag (..)
   , testEventAttrFlag
   )where

import Data.Word (Word64, Word32, Word16, Word8, Word)
import Text.PrettyPrint (text, (<+>), ($$), render, empty, integer, (<>), hsep, Doc)
import Data.ByteString.Lazy (ByteString)
import Profiling.Linux.Perf.Pretty (Pretty (..), showBits)
import Data.Bits (testBit)

-- -----------------------------------------------------------------------------
-- Event data types

{-
data Event = Event { ev_type    :: EventType,
                     ev_cpumode :: EventCPUMode,
                     ev_size    :: Word16,
                     ev_data    :: [Word8] }
-}

data Event =
   Event
   { ev_header :: EventHeader
   , ev_payload :: EventPayload
   }

instance Pretty Event where
   pretty ev@(Event {}) =
      text "header: " <+> (pretty $ ev_header ev) $$
      text "payload: " <+> (pretty $ ev_payload ev)

-- XXX should probably get this from the definintion of the C type
data EventType -- perf_event_header->type
   = PERF_RECORD_MMAP       -- 1
   | PERF_RECORD_LOST       -- 2
   | PERF_RECORD_COMM       -- 3
   | PERF_RECORD_EXIT       -- 4
   | PERF_RECORD_THROTTLE   -- 5
   | PERF_RECORD_UNTHROTTLE -- 6
   | PERF_RECORD_FORK       -- 7
   | PERF_RECORD_READ       -- 8
   | PERF_RECORD_SAMPLE     -- 9
   | PERF_RECORD_UNKNOWN Int  -- possibly a bad number?
   deriving (Eq, Show)

instance Enum EventType where

   toEnum 1 = PERF_RECORD_MMAP
   toEnum 2 = PERF_RECORD_LOST
   toEnum 3 = PERF_RECORD_COMM
   toEnum 4 = PERF_RECORD_EXIT
   toEnum 5 = PERF_RECORD_THROTTLE
   toEnum 6 = PERF_RECORD_UNTHROTTLE
   toEnum 7 = PERF_RECORD_FORK
   toEnum 8 = PERF_RECORD_READ
   toEnum 9 = PERF_RECORD_SAMPLE
   toEnum other = PERF_RECORD_UNKNOWN other

   fromEnum PERF_RECORD_MMAP = 1
   fromEnum PERF_RECORD_LOST = 2
   fromEnum PERF_RECORD_COMM = 3
   fromEnum PERF_RECORD_EXIT = 4
   fromEnum PERF_RECORD_THROTTLE = 5
   fromEnum PERF_RECORD_UNTHROTTLE = 6
   fromEnum PERF_RECORD_FORK = 7
   fromEnum PERF_RECORD_READ = 8
   fromEnum PERF_RECORD_SAMPLE = 9
   fromEnum (PERF_RECORD_UNKNOWN other) = other

instance Pretty EventType where
   pretty = text . show

data SampleFormat
   = PERF_SAMPLE_IP        -- 1U << 0
   | PERF_SAMPLE_TID       -- 1U << 1
   | PERF_SAMPLE_TIME      -- 1U << 2
   | PERF_SAMPLE_ADDR      -- 1U << 3
   | PERF_SAMPLE_READ      -- 1U << 4
   | PERF_SAMPLE_CALLCHAIN -- 1U << 5
   | PERF_SAMPLE_ID        -- 1U << 6
   | PERF_SAMPLE_CPU       -- 1U << 7
   | PERF_SAMPLE_PERIOD    -- 1U << 8
   | PERF_SAMPLE_STREAM_ID -- 1U << 9
   | PERF_SAMPLE_RAW       -- 1U << 10
   deriving (Eq, Enum, Show)

instance Pretty SampleFormat where
   pretty = text . show

data EventCPUMode -- a bitfield in perf_event_header->misc
   = PERF_RECORD_CPUMODE_UNKNOWN -- 0
   | PERF_RECORD_MISC_KERNEL     -- 1
   | PERF_RECORD_MISC_USER       -- 2
   | PERF_RECORD_MISC_HYPERVISOR -- 3
   deriving (Eq, Show)

instance Pretty EventCPUMode where
   pretty = text . show

-- Corresponds with the perf_file_section struct in <perf source>/util/header.h
data FileSection
  = FileSection {
       sec_offset :: Word64,   -- File offset to the section.
       sec_size   :: Word64    -- Size of the section in bytes.
    }

instance Pretty FileSection where
   pretty fs = text "offset:" <+> pretty (sec_offset fs) $$
               text "size:" <+> pretty (sec_size fs)

-- Corresponds with the perf_file_header struct in <perf source>/util/header.h
data FileHeader
   = FileHeader {
        fh_size          :: Word64,    -- Size of (this) header.
        fh_attr_size     :: Word64,    -- Size of one attribute section.
        fh_attrs_offset  :: Word64,    -- File offset to the attribute section.
        fh_attrs_size    :: Word64,    -- Size of the attribute section in bytes.
        fh_data_offset   :: Word64,    -- File offset to the data section.
        fh_data_size     :: Word64,    -- Size of the data section in bytes.
        fh_event_offset  :: Word64,    -- File offset to the event section.
        fh_event_size    :: Word64,    -- Size of the event section in bytes.
        fh_adds_features :: [Word32]   -- Bitfield. XXX what is this for?
     }

instance Pretty FileHeader where
   pretty fh =
      text "size:" <+> pretty (fh_size fh) $$
      text "attribute size:" <+> pretty (fh_attr_size fh) $$
      text "attributes offset:" <+> pretty (fh_attrs_offset fh) $$
      text "attributes size:" <+> pretty  (fh_attrs_size fh) $$
      text "data offset:" <+> pretty (fh_data_offset fh) $$
      text "data size:" <+> pretty (fh_data_size fh) $$
      text "event offset:" <+> pretty (fh_event_offset fh) $$
      text "event size:" <+> pretty (fh_event_size fh) $$
      text "features:" <+> hsep (Prelude.map pretty $ fh_adds_features fh)

-- See struct perf_event_attr in linux/perf_event.h
data EventAttrFlag
   = Disabled              -- off by default
   | Inherit               -- children inherit it
   | Pinned                -- must always be on PMU
   | Exclusive             -- only group on PMU
   | ExcludeUser           -- don't count user
   | ExcludeKernel         -- ditto kernel
   | ExcludeHV             -- ditto hypervisor
   | ExcludeIdle           -- don't count when idle
   | Mmap                  -- include mmap data
   | Comm                  -- include comm data
   | Freq                  -- use freq, not period
   | InheritStat           -- per task counts
   | EnableOnExec          -- next exec enables
   | Task                  -- trace fork/exit
   | WaterMark             -- wakeup_watermark

   -- precise_ip
   -- See also PERF_RECORD_MISC_EXACT_IP
   | ArbitrarySkid
   | ConstantSkid
   | RequestedZeroSkid
   | CompulsoryZeroSkid

   | MmapData              -- non-exec mmap data
   | SampleIdAll           -- sample_type all events
   deriving (Eq, Ord, Enum, Show)

instance Pretty EventAttrFlag where
   pretty Disabled = text "disabled"
   pretty Inherit = text "inherit"
   pretty Pinned = text "pinned"
   pretty Exclusive = text "exclusive"
   pretty ExcludeUser = text "exclude-user"
   pretty ExcludeKernel = text "exclude-kernel"
   pretty ExcludeHV = text "exclude-hypervisor"
   pretty ExcludeIdle = text "exclude-idle"
   pretty Mmap = text "mmap"
   pretty Comm = text "comm"
   pretty Freq = text "freq"
   pretty InheritStat = text "inherit-stat"
   pretty EnableOnExec = text "enable-on-exec"
   pretty Task = text "task"
   pretty WaterMark = text "watermark"
   pretty ArbitrarySkid = text "arbitrary-skid"
   pretty ConstantSkid = text "constant-skid"
   pretty RequestedZeroSkid = text "requested-zero-skid"
   pretty CompulsoryZeroSkid = text "compulsory-zero-skid"
   pretty MmapData = text "mmap-data"
   pretty SampleIdAll = text "sample-id-all"

-- Test if a given EventAttrFlag is set.
-- Tedious definition because of the way the skid flags are
-- implemented as a 2 bit word instead of individual single bits.
testEventAttrFlag :: Word64 -> EventAttrFlag -> Bool
testEventAttrFlag word flag =
   case flag of
      Disabled           -> testBit word 0
      Inherit            -> testBit word 1
      Pinned             -> testBit word 2
      Exclusive          -> testBit word 3
      ExcludeUser        -> testBit word 4
      ExcludeKernel      -> testBit word 5
      ExcludeHV          -> testBit word 6
      ExcludeIdle        -> testBit word 7
      Mmap               -> testBit word 8
      Comm               -> testBit word 9
      Freq               -> testBit word 10
      InheritStat        -> testBit word 11
      EnableOnExec       -> testBit word 12
      Task               -> testBit word 13
      WaterMark          -> testBit word 14
      ArbitrarySkid      -> not (testBit word 15) && not (testBit word 16)
      ConstantSkid       -> not (testBit word 15) && (testBit word 16)
      RequestedZeroSkid  -> (testBit word 15) && not (testBit word 16)
      CompulsoryZeroSkid -> (testBit word 15) && (testBit word 16)
      MmapData           -> testBit word 17
      SampleIdAll        -> testBit word 18

prettyFlags :: Word64 -> Doc
prettyFlags word = foldr testFlag empty [toEnum 0 ..]
   where
   testFlag :: EventAttrFlag -> Doc -> Doc
   testFlag flag rest
      | testEventAttrFlag word flag = pretty flag <+> rest
      | otherwise = rest

-- Corresponds with the perf_event_attr struct in <perf source>/util/perf_event.h
data EventAttr
   = EventAttr {
        ea_type :: Word32,   -- Major type: hardware/software/tracepoint/etc.
        ea_size :: Word32,   -- Size of the attr structure, for fwd/bwd compat.
        ea_config :: Word64, -- Link to .event id of perf trace event type.

        -- number of events when a sample is generated if .freq
        -- is not set or frequency for sampling if .freq is set
        ea_sample_period_or_freq :: Word64,
        ea_sample_type :: Word64,        -- information about what is stored in the sampling record
        ea_read_format :: Word64,        -- XXX what is this for?
        ea_flags :: Word64,              -- this is a bitfield
        ea_wakeup_events_or_watermark :: Word32, -- wakeup every n events or bytes before wakeup
        ea_bp_type :: Word32,            -- XXX what is this for?
        ea_bp_addr_or_config1 :: Word64, -- XXX what is this for?
        ea_bp_len_or_config2 :: Word64   -- XXX what is this for?
     }

instance Pretty EventAttr where
   pretty ea =
      text "type:" <+> pretty (ea_type ea) $$
      text "size:" <+> pretty (ea_size ea) $$
      text "config:" <+> pretty (ea_config ea) $$
      text "sample period or frequency:" <+> pretty (ea_sample_period_or_freq ea) $$
      text "sample type:" <+> pretty (ea_sample_type ea) $$
      text "read format:" <+> pretty (ea_read_format ea) $$
      text "flags:" <+> prettyFlags (ea_flags ea) $$
      text "wakeup events or watermark:" <+> pretty (ea_wakeup_events_or_watermark ea) $$
      text "bp type:" <+> pretty (ea_bp_type ea) $$
      text "bp address or config1:" <+> pretty (ea_bp_addr_or_config1 ea) $$
      text "bp length or config2:" <+> pretty (ea_bp_len_or_config2 ea)

data FileAttr = FileAttr {
   fa_attr :: EventAttr,
   fa_ids_offset :: Word64, -- File offset to the ids section.
   fa_ids_size   :: Word64  -- Size of the ids section in bytes.
}

instance Pretty FileAttr where
   pretty fa =
      text "event attribute:" <+> pretty (fa_attr fa) $$
      text "ids offset:" <+> pretty (fa_ids_offset fa) $$
      text "ids size:" <+> pretty (fa_ids_size fa)

data TraceEventType = TraceEventType {
   te_event_id :: Word64, -- This entry belongs to the perf event attr entry where .config
                          -- has the same value as this id.
   te_name :: ByteString
}

instance Pretty TraceEventType where
   pretty te =
      text "event id:" <+> pretty (te_event_id te) $$
      text "name:" <+> pretty (te_name te)

-- Corresponds with the perf_event_header struct in <perf source>/util/perf_event.h
data EventHeader = EventHeader {
   eh_type :: EventType,
   eh_misc :: Word16,
   eh_size :: Word16
}

instance Pretty EventHeader where
   pretty eh =
      text "type:" <+> pretty (eh_type eh) $$
      text "misc:" <+> pretty (eh_misc eh) $$
      text "size:" <+> pretty (eh_size eh)

data EventPayload =
   -- Corresponds with the comm_event struct in <perf source>/util/event.h (without the header)
   CommEvent {
      ce_pid :: Word32,  -- process id
      ce_tid :: Word32,  -- thread id
      ce_comm :: ByteString -- name of the application
   }
   -- Corresponds with the mmap_event struct in <perf source>/util/event.h (without the header)
   | MmapEvent {
      me_pid :: Word32,     -- process id
      me_tid :: Word32,     -- thread id
      me_start :: Word64,   -- start of memory range
      me_len :: Word64,     -- size of memory range
      me_pgoff :: Word64,   -- page offset? XXX what is this for?
      me_filename :: ByteString -- binary file using this range
   }
   -- Corresponds with the fork_event struct in <perf source>/util/event.h (without the header)
   | ForkEvent {
      fe_pid :: Word32,    -- process id
      fe_ppid :: Word32,   -- parent proecess id
      fe_tid :: Word32,    -- thread id
      fe_ptid :: Word32,   -- parent thread id
      fe_time :: Word64    -- timestamp
   }
   -- Corresponds with the exit_event struct in <perf source>/util/event.h (without the header)
   | ExitEvent {
      ee_pid :: Word32,    -- process id
      ee_ppid :: Word32,   -- parent proecess id
      ee_tid :: Word32,    -- thread id
      ee_ptid :: Word32,   -- parent thread id
      ee_time :: Word64    -- timestamp
   }
   -- Corresponds with the lost_event struct in <perf source>/util/event.h (without the header)
   | LostEvent {
      le_id :: Word64,
      le_lost :: Word64
   }
   -- Corresponds with the read_event struct in <perf source>/util/event.h (without the header)
   | ReadEvent {
      re_pid :: Word32,
      re_tid :: Word32,
      re_value :: Word64,
      re_time_enabled :: Word64,
      re_time_running :: Word64,
      re_id :: Word64
   }
   | SampleEvent {
      se_ip :: Maybe Word64,
      se_pid :: Maybe Word32,
      se_tid :: Maybe Word32,
      se_time :: Maybe Word64,
      se_addr :: Maybe Word64,
      se_id :: Maybe Word64,
      se_streamid :: Maybe Word64,
      se_cpu :: Maybe Word32,
      se_period :: Maybe Word64
   }
   -- ThrottleEvent and UnThrottleEvent are mentioned in
   -- <system include directory>/linux/perf_event.h
   -- but does not appear in <perf source>/util/event.h
   | ThrottleEvent {
      te_time :: Word64,
      te_id :: Word64,
      te_stream_id :: Word64
   }
   | UnThrottleEvent {
      ue_time :: Word64,
      ue_id :: Word64,
      ue_stream_id :: Word64
   }
   | UnknownEvent -- Something to return if we find PERF_RECORD_UNKNOWN
   deriving (Show)

instance Pretty EventPayload where
   pretty ce@(CommEvent{}) =
      text "pid:" <+> pretty (ce_pid ce) $$
      text "tid:" <+> pretty (ce_tid ce) $$
      text "comm:" <+> pretty (ce_comm ce)
   pretty me@(MmapEvent{}) =
      text "pid:" <+> pretty (me_pid me) $$
      text "tid:" <+> pretty (me_tid me) $$
      text "start:" <+> pretty (me_start me) $$
      text "len:" <+> pretty (me_len me) $$
      text "pgoff:" <+> pretty (me_pgoff me) $$
      text "filename:" <+> pretty (me_filename me)
   pretty fe@(ForkEvent{}) =
      text "pid:" <+> pretty (fe_pid fe) $$
      text "ppid:" <+> pretty (fe_ppid fe) $$
      text "tid:" <+> pretty (fe_tid fe) $$
      text "ptid:" <+> pretty (fe_ptid fe) $$
      text "time:" <+> pretty (fe_time fe)
   pretty ee@(ExitEvent{}) =
      text "pid:" <+> pretty (ee_pid ee) $$
      text "ppid:" <+> pretty (ee_ppid ee) $$
      text "tid:" <+> pretty (ee_tid ee) $$
      text "ptid:" <+> pretty (ee_ptid ee) $$
      text "time:" <+> pretty (ee_time ee)
   pretty le@(LostEvent {}) =
      text "id:" <+> pretty (le_id le) $$
      text "lost:" <+> pretty (le_lost le)
   pretty se@(SampleEvent {}) =
      text "ip:" <+> pretty (se_ip se) $$
      text "pid:" <+> pretty (se_pid se) $$
      text "tid:" <+> pretty (se_tid se) $$
      text "time:" <+> pretty (se_time se) $$
      text "addr:" <+> pretty (se_addr se) $$
      text "id:" <+> pretty (se_id se) $$
      text "streamid:" <+> pretty (se_streamid se) $$
      text "cpu:" <+> pretty (se_cpu se) $$
      text "period:" <+> pretty (se_period se)
   pretty te@(ThrottleEvent {}) =
      text "time:" <+> pretty (te_time te) $$
      text "id:" <+> pretty (te_id te) $$
      text "stream_id:" <+> pretty (te_stream_id te)
   pretty ue@(UnThrottleEvent {}) =
      text "time:" <+> pretty (ue_time ue) $$
      text "id:" <+> pretty (ue_id ue) $$
      text "stream_id:" <+> pretty (ue_stream_id ue)
   pretty UnknownEvent = text "Unknown"
