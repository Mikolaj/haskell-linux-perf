linux-perf
==========

linux-perf is a library for parsing, representing in Haskell
and pretty-printing the data file output of the Linux 'perf'
command (Linux performance counters).

License and Copyright
---------------------

linux-perf is distributed as open source software under the terms of the BSD
License (see the file LICENSE in the top directory).

Authors: Simon Marlow, Bernie Pope, Mikolaj Konarski, Duncan Coutts, copyright 2010, 2011, 2012.

Contact information
-------------------

Email Bernie Pope:

    florbitous_at_gmail_dot_com

Building and installing
-----------------------

linux-perf uses the cabal infrastructure for configuring, building
and installation. It needs access to the header files from the Linux
kernel source distribution (one that is sufficiently recent to support
the performance counters tool).

To build and install:

    cabal install --extra-include-dirs=/path/to/linux/headers/

To clean:

    cabal clean

To test:

    dump-perf test/ParFib.perf.data | less

For longer examples see README.ghc-events-perf.md.
