\ strand - limits

.( limits )

h# 4000 constant MAXATOMS   \ must be a power of 2
256 k constant STATICBUF    \ space for strings 
128 k constant MAXPROCS     \ max number of processes
1 k cells constant ENTRY_RESERVE   \ before GC kicks in
10 constant TIMESLICE       \ granularity of process creation
10000000 constant HEAPSIZE  \ size of GC'd heap (half used)
256 constant MAX_MODULES    \ number of modules loaded
256 constant MAX_BUILTINS   \ size of builtin-table
8 constant MAX_LIBPATH      \ max number of library dirs
10 constant LOGLIMIT        \ number of items printed in log
100 constant ERRLIMIT       \ number of items in error msg
16 k k constant IMAGESIZE   \ total size of Forth heap
32 k constant PORT_SIZE      \ also limits compiled modules
PORT_SIZE 10 / constant PORT_RESERVE \ after this send vars
" strand.msg" 2constant MSGFILE \ default name
256 constant #RBUCKETS       \ buckets in remotes hash table
32 constant MAX_LISTEN      \ max fds listened for input
16 constant PTICKS          \  poll-ticks (power of 2)
5 constant DROPPTICKS       \ p-ticks before dropping remote
50 constant LOCK_ATTEMPTS   \ send: yield after lock tries
256 constant MAX_GLOBALS    \ max number of globals
500 constant MAX_TIMEOUT    \ timeout when listening/sleeping
100 constant MAX_IDLE       \ maximal sleep when pausing
10 constant PAUSE_SHIFT     \ shift for pause sleep time
" .sm" 2constant MOD_EXTENSION  \ default extension for mods
1024 constant MAX_PORTVALS  \ maximal number of port objects
