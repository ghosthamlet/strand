\ Strand - loader

include limits.f
include conf.f
include log.f
include gc.f
include val.f
include vm.f
include ipc.f
include bclib.f
include bc.f
include dbg.f
include version.f
[defined] openbsd  [if]
include OpenBSD.f
[then]
[defined] linux  [if]
include Linux.f
[then]
[defined] darwin  [if]
include Darwin.f
[then]
include lib.f

2variable process0      create p0 ," main"      
p0 count process0 2!
: gcstrand  gcval  gcvm  gcipc ;       ' gcstrand is gctraceroots 
: usage  ( u -- ) ." usage: "  0 arg type  
  ."  [-h] [-s] [-hs] [-d] [-v] [-l FILENAME] [-p PROCESS] [-i DIRECTORY] [-f FILENAME] [-P PORT] [-r SHIFT] [-m MACHINE] FILENAME ... [-- ...]"  cr  bye ;
: setlog  ( a u -- ) 2dup s" -" compare 0=  if  1 logfile !  2drop  
    else  openlog  then  logging on ;
: setprocess  ( a u -- ) process0 2! ;
: setiport  ( a u -- ) number 0=  if  1 usage  |  portx ! ;
: setmachine  ( a u -- ) number 0=  if  1 usage  |  machine-id ! ;
: setshift  ( a u -- ) number 0=  if  1 usage  |  pauseshift ! ;
: cmdarg  ( u1 -- u2 ) dup arg
    2dup s" -h" compare 0=  if  0 usage  |
    2dup s" -d" compare 0=  if  2drop  debugging on  1  |
    2dup s" -l" compare 0=  if  2drop  1+ arg setlog  2  |
    2dup s" -r" compare 0=  if  2drop  1+ arg setshift  2  |
    2dup s" -f" compare 0=  if  2drop  1+ arg msgfile 2!  2  |
    2dup s" -p" compare 0=  if  2drop  1+ arg setprocess  2  |
    2dup s" -P" compare 0=  if  2drop  1+ arg setiport  2  |
    2dup s" -i" compare 0=  if  2drop  1+ arg addlib  2  |
    2dup s" -s" compare 0=  if  2drop  3 statistics !  1  |
    2dup s" -hs" compare 0=  if  2drop  2 statistics !  1  |
    2dup s" -m" compare 0=  if  2drop  1+ arg setmachine  2  |
    2dup s" -v" compare 0=  if  strand-version .  cr  bye  |
    2dup s" --" compare 0=  if  2drop  dup 1+ firstarg !  #arg diff  |
    over c@ [char] - =  if  1 usage  |
    intern load_module drop  1 ;
defer cmdline
: (cmdline)  #arg  1  ?do  i cmdarg  +loop ;
' (cmdline) is cmdline
: exitfail  <log  cr  ." aborted"  log>  writelimit off  stopnode  1 exitcode ;
: activate_proc  ( atm mod -- f )  0  swap  
  (find_export) ?dup  if  make_process enqueue  true  |  false ;      
: activate_mod  ( a1 u1 a2 u2 -- ) intern push  intern
  find_module  pop swap activate_proc 
  0= abort" entry point not found" ;
: activate_any  ( a u -- ) intern  #mtable @  0  do
    dup  %mtable i th @  activate_proc drop loop  drop ;
: activate_def  s" $start" activate_any ;      
: activate  #mtable @ 0=  if  <fatal ." no modules loaded"  fatal>  |
  make_task dup %task0 !  0integer over task.id !
  0integer swap task.count !  \ `make_process` bumps the count
  activate_def  process0 2@ [char] : split 2swap ?dup  if
    1 /string activate_mod  else  drop activate_any  then ;    
: handlers  [defined] handle  [if]
    SIGINT handle  SIGTERM handle  SIGCHLD handle  
    SIGHUP handle  SIGALRM handle
  [then] ;
: start  ['] exitfail is abort  pid node-id !  time starttime !
  handlers  MSGFILE msgfile 2! 
  align  here HEAPSIZE dup allot gcinit  cmdline  
  initmsg  load_main  time seed !
  initevents  startnode  activate  r> drop  schedule ;
: run  activate  schedule ;
: make  ( | filename -- ) cr  ['] start is startup  
  IMAGESIZE enlarge  save  bye ;
: deinit  <log  cr  .room  cr  log>   exitmsg ;
' deinit is stophook
: .heapstats  statistics @ 2 and  if  <log  .breakdown  log>  then ;
' .heapstats is gchook

\ predefined symbols + some global variable initializations:
" []" intern %[] !  " ." intern %. !  " merge" intern %merge !
" send_read" intern %send_read !  
" send_call" intern %send_call !
" send_value" intern %send_value !  
" send_get_module" intern %send_get_module !
" send_addref" intern %send_addref !
" send_assign_port" intern %send_assign_port !
%[] @ %peers !      %[] @ %listening !  
%[] @ %dropremotes !  %[] @ %children !
[defined] linux  [if]  " linux"  [then]
[defined] darwin  [if]  " darwin"  [then]
[defined] openbsd  [if]  " openbsd"  [then]
  intern %os !
[defined] arm  [if]  " arm"  [then]
[defined] x86_64  [if]  " x86_64"  [then]
[defined] ppc64  [if]  " ppc64"  [then]
[defined] aarch64  [if]  " aarch64"  [then]
  intern %arch !
%[] @ %failure !
" " intern %'' !    " /" intern %/ !
" success" intern %success !   " fail" intern %fail !
" suspend" intern %suspend !   " resume" intern %resume !
" none" intern %none !  " file" intern %file !
" directory" intern %directory !  " link" intern %link !

\ default library paths:
" ." addlib  " lib" addlib

depth  [if]  cr .( *** debris on stack )  abort  [then]
