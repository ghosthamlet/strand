\ Strand - VM

.( vm )

1 constant SIGHUP          14 constant SIGALRM
2 constant SIGINT           15 constant SIGTERM
[defined] linux  [if]  17  [else]  20  [then]  constant SIGCHLD

MAXPROCS cells buffer: pbuffer
variable pqstart        variable pqend      variable #suspended
pbuffer dup pqstart ! pqend !
variable retry
variable #r-total    variable #s-total      variable #procmax
variable starttime
variable #spcount
variable timeslice      TIMESLICE timeslice !
variable clock      variable tscount    timeslice @ tscount !
variable %me      variable %listening     variable statistics
variable %children      variable %timer
variable %success     variable %fail
variable %suspend    variable %resume
variable %failure       variable %idlevar
defer starthook   ' noop is starthook
defer stophook   ' noop is stophook
defer reap      defer idleness

defer poll_input  ( to -- )        defer check_task
: .self  ." ["  node-id @ (.) type  [char] : emit
  machine-id @ (.) type  [char] : emit  self 255 and (.) type  ." ]" ;
: #proc  ( -- u ) pqend @ pqstart @ - abs 1 cells / ;
: dumpproc  ( p -- )
  %me @
  dup process.id @ dwrite space
  dup process.loc @ dwrite space
  dup process.args @ dwrite space
  dup process.env @ dwrite space  cr ;
defer .stats
: task  ( -- tup ) %me @ process.task @ ;
: .task  task (.task)  space ;
: startnode  <log  .self ."  started"  cr  log>  starthook  .stats
  gchook ( for initial heap stats )   make_var %idlevar ! ;
: stopnode  stophook  <log  .self  ."  stopped"  cr  log> ;
: .where  %me @ ?dup 0= ?exit
  process.loc @ ?dup  if  bdata type  ." : "  then ;
: .clock  clock ?  ." | " ;
: .info  .clock  %me @ write  space  .where ;
: deadlock
  <fatal  ." deadlock with "  #suspended ?  ." processes suspended"
  fatal> ;
: finish  <log  ." all processes terminated"  cr  log>  stopnode
  bye ;
variable pausesleep      
variable pauseshift      PAUSE_SHIFT pauseshift !
defer reclaimports
: busy  pausesleep off ;
: pause  pauseshift @ dup 0=  if  ms  |
  1 pausesleep +!  pausesleep @ swap rshift ms ;
: children?  ( -- 0|1 ) %children @ %[] @ <> 1 and ;
: listening?  ( -- 0|1 ) %listening @ %[] @ <> 1 and ;
: timing?  ( -- 0|1 ) %timer @ 0= invert 1 and ;
: done
  #suspended @ 0=  if  finish  then
  idleness
  children? 2*  timing? 2* or  listening?  or   \ test combination
  1  ->  -1 poll_input  |
  2  ->  MAX_TIMEOUT ms  |
  3  ->  MAX_TIMEOUT poll_input  |
  reclaimports
  drop  deadlock ;
: qempty?  ( -- f ) pqstart @ pqend @ = ;
: pqwrap  ( a1 -- a2 ) pbuffer - MAXPROCS cells mod
  pbuffer + ;
: pargs  ( a -- ) %me @ process.args @ ;
: initproc  ( p -- )  pargs over process.args !
  %me @ process.env @ swap process.env ! ;
: make_task  ( -- task )
  5 (make_tuple)  id integer over task.id !
  make_var over task.status !  make_var over task.control !
  1 integer over task.count ! ;
: make_process ( ip -- p ) /process gcalloc
  PROCESS_TAG tagged
  %me @  if
    task over process.task !
    %me @ process.loc @ over process.loc !
  else
    %task0 @ over process.task !
  then
  1 over process.task @ task.count int+!
  tuck  process.ip !  id integer over process.id !
  %me @   if  dup push initproc pop  then ;
: setip  ( ip -- ) %me @ process.ip ! ;
: remember  r@ setip ;
: penv  ( -- e ) %me @ process.env @ ;
: arguments  ( .... u -- ) 3 nogc !
  dup cells gcalloc dup  %me @ process.args !  over th
  swap  0  ?do  1 cells - swap ?deref over !  loop  drop  nogc off
  <dlog  .info  ." entry with " pargs write  cr  log>
  \ in case task is freshly invoked in suspended state:
  r@ setip  check_task ;
: environment  ( u -- ) dup  if  cells gcalloc  else  0  then
  %me @ process.env !  
  1 #r-total +! ;
: jump  ( a -- ) r> drop  @  >r ;
: try  ( [ip] -- ) r@ @+ retry !  r> 1 cells - setip  >r ;
: mismatch  <dlog  .info
    ." retry @ "  retry ?  ." with "  pargs write  cr  log>
    clear  reset  retry @  >r ;
: ?mismatch  ( f -- ) 0= ?exit  mismatch ;
: setloc  ( atm -- ) %me @ process.loc ! ;
: gcliteral  ( -- x ) r> dup @  swap cell+ cell+ >r ;
: r/s  ( -- u ) #r-total @  time starttime @ - ?dup  if  u/  then ;

: getarg0  pargs @ ;
: getarg1  pargs cell+ @ ;
: getarg2  pargs [ 2 cells literal ] + @ ;
: getarg3  pargs [ 3 cells literal ] + @ ;
: getarg4  pargs [ 4 cells literal ] + @ ;
: getarg5  pargs [ 5 cells literal ] + @ ;
: getarg6  pargs [ 6 cells literal ] + @ ;
: getarg7  pargs [ 7 cells literal ] + @ ;
: get_argument  ( u -- x ) pargs swap th @ ;
: getenv0  penv @ ;
: getenv1  penv cell+ @ ;
: getenv2  penv [ 2 cells literal ]  + @ ;
: getenv3  penv [ 3 cells literal ]  + @ ;
: getenv4  penv [ 4 cells literal ]  + @ ;
: getenv5  penv [ 5 cells literal ]  + @ ;
: getenv6  penv [ 6 cells literal ]  + @ ;
: getenv7  penv [ 7 cells literal ]  + @ ;
: get_env  ( u -- x ) penv swap th @ ;
: putenv0  penv ! ;
: putenv1  penv cell+ ! ;
: putenv2  penv [ 2 cells literal ] + ! ;
: putenv3  penv [ 3 cells literal ] + ! ;
: putenv4  penv [ 4 cells literal ] + ! ;
: putenv5  penv [ 5 cells literal ] + ! ;
: putenv6  penv [ 6 cells literal ] + ! ;
: putenv7  penv [ 7 cells literal ] + ! ;
: put_env  ( x u -- ) penv swap th ! ;

defer resolve_module    ( mname -- mod )
\ patches calling code to jump directly to process-definition
: call_module  ( [mname] [name] [arity] -- ) r@ @+  resolve_module
  >r  @+ swap @ r> find_export dup r@ !  ['] (else) r> 1 cells - !  >r ;
: module_ref*  ( [mid] [pdix] -- pdix mid )
  r> @+  swap @+ integer  swap >r  swap ;
: module_ref  ( tup [mname] [xname] -- [mid] [pdix] tup pdix mid )
  push  ['] module_ref* r@ 1 cells - !
  r@ @ resolve_module  dup push mod.id @ r@ !
  r@ cell+ @  pop  top size  swap  find_pdix r@ cell+ !
  r> 1 cells - >r  pop ;

: gcvm  %me gctrace!  %listening gctrace!  %idlevar gctrace!
  %children gctrace!  %task0 gctrace!  %failure gctrace!
  %timer gctrace!
  #mtable @  0  ?do  %mtable i th gctrace!  loop
  pqstart @  begin  dup pqend @ <> while  dup gctrace!
    cell+ pqwrap  repeat  drop ;

defer trigger-timer
defer interrupts
: (interrupts)  [defined] signal?  [if]
  SIGALRM signal?  if  trigger-timer  then
  SIGINT signal?  SIGTERM signal?  or  if
    <log  ." terminated by signal"  cr  log>
    stopnode  bye  then
  SIGCHLD signal?  if  reap  then
  SIGHUP signal?  if
    2 logfile !   logging on  <fatal  ." SIGHUP"  fatal>  then
  [then] ;  ' (interrupts) is interrupts
: enqueue  ( p -- )
  pqend @ cell+ pqstart @ = abort" too many processes"
  pqend @ swap !+  pqwrap pqend ! ;
: dequeue  ( -- p )
  begin  qempty?  while  done  interrupts  repeat
  pqstart @ @+ swap pqwrap pqstart !  ;
defer msg_hook    ' noop is msg_hook
: poll_tick  clock @ PTICKS 1- and 0=  if
    .stats  0 poll_input  dodrops  1 pclock +!  then ;
: schedule
  1 clock +!  timeslice @ tscount !  poll_tick
  clear  reset  tmpclear  interrupts  msg_hook
  #proc #procmax @ max #procmax !  dequeue dup %me !
\ dup dumpproc
  process.ip @ >r  check_task ;
: yield  %me @ enqueue  schedule ;
: reserve  ENTRY_RESERVE ?heap ;
: pfork  reserve  r@ cell+ make_process  enqueue
  r> @ dup setip >r ;
: tail_fork  reserve tscount @ 1- ?dup 0=  if
    r> make_process enqueue
    schedule  |
  tscount !  r@ setip ;
: failed  <err" match failure"  .reason  ." : "  %me @ process.args @
  ?deref  write  err> ;

variable resumemark     \ defaults to 0, may be UNIDLED
: resume  ( v -- )
  dup var.deps @  begin  ?dup  while  -1 #suspended +!
   <dlog %me @ >r  dup %me !  .info  ." resumes on "
    over writevarid  r> %me !  cr  log>
    dup enqueue  process.next dup @  resumemark @ rot !
    -1 #spcount +!
  repeat
  var.deps off ;
: suspend  ( v -- )
  1 #s-total +!   1 #spcount +!
  <dlog .info  ." suspends on "  dup writevarid cr  log>
  dup var.deps @  %me @ process.next !  1 #suspended +!
  %me @ swap var.deps !  schedule ;

defer remoteref  ( rem -- x )
: deref  ( x -- x' ) 
   begin
     dup remote?  if  remoteref   else
        +var  dup var.val @ 2dup =  if  drop  suspend  |
        \ "collapse" chains of var-bindings
        dup var?  if  2dup var.val @  swap var.val !  then
        nip  1 #derefs +!   
    then
  again ;
: (deref*)  ( x -- )
  begin  deref
    dup gcblock? 0=  if  drop  |
    dup binary?  if  drop  |
    dup port?  if  drop  |
    dup size  0  ->  drop  |
    1-  0  ?do  dup i th @ recurse  loop 
    dup size 1- th @
  again ;
: deref*  ( x -- x' ) deref dup (deref*) ;
: var!  ( x v -- ) tuck var.val !  resume ;
defer remoteassign     ( x rem -- )
: (assign)  ( x v -- )
  <dlog  .info  ." assigning " over write  ."  to "  dup write  cr  log>  
  var! ;
: assign  ( v x -- ) ?deref  swap ?deref
  dup remote?  if  remoteassign  |
  dup var? 0=  if
    <err" assignment to non-variable"  .reason  ." : "  write  ."  value: "
       dwrite  err>  |
  (assign) ;
: (closeport)  ( var -- )  %[] @ swap var! ;
' (closeport) is closeport

: task_drop  -1 task task.count int+! ;
: terminate  task_drop
  task task.count @ get_int 0=  if
    <dlog  .task  ." succeeded" cr log>
    task task.status @ %success @ assign
  then  schedule ;

\ errors
: fatal_error:  errout  decimal  cr  .self  ."  Error: "
  .where ;   ' fatal_error: is <fatal
: (fatal>)  cr  1 stdout !  writelimit off  abort ;  ' (fatal>) is fatal>
: error:  %me @ 0=  if  r> cell+ >r  fatal_error:  |
  task %task0 @ =  if  r> cell+ >r  fatal_error:  |
  logging @  if
    LOGLIMIT limited  logout  .task  ." failed: "
    r> cell+ >r
  else  
    r> @ >r  
  then ;
' error: is (<err)
: error_end  
  logging @  if  cr  then  1 stdout !  writelimit off
  %me @  if  task  else  0  then  %task0 @ <>  if
    depth logdepth !  (log>)
    morespace  %failure @  %fail @ 2 make_tuple
    task task.status @ swap assign  %[] @ %failure !  schedule
  then  fatal> ;
' error_end is (err>)
: (reason)  ( a u -- ) intern %failure ! ; ' (reason) is reason
: (.reason)  %failure @ write ;  ' (.reason) is .reason

\ Input-polling
/pollfd MAX_LISTEN * buffer: pollinfo
variable relisten      variable #polling
variable >prev_listen
: poll_resume  ( [fd|var] -- ) 
  >prev_listen @ dup @ cdr swap !
  cdr  %[] @ assign  relisten on ;
: collect_polls
  pollinfo >r  %listening @  #polling off
  begin  dup %[] @ <>  while
    dup car car get_int r@ poll.fd!  POLLIN r@ poll.ev!  r> /pollfd + >r
    cdr  1 #polling +!
  repeat  r> 2drop  relisten off ;
: activate_fds
  pollinfo  %listening dup >prev_listen ! @
  begin  %[] @  ->  drop  |
    over poll.rev@ dup POLLERR and  if
      <err" poll(2) failed"  .reason  ."  with error "   err>  then
    POLLIN POLLHUP or and  if  
      dup car poll_resume  cdr
    else
      list.tail dup >prev_listen ! @  
    then
    /pollfd under+  
  again ;
: (poll_input)  ( timeout -- )
  relisten @  if  collect_polls  then
  #polling @ 0=  if  drop  |
  pollinfo  #polling @  rot  poll  nip ?exit
  activate_fds ;
' (poll_input) is poll_input

\ clause-indexing + lookup tables
: lookup_arg  ( -- x1 x2 ) pargs @  0integer ;
: lookup_tuple  ( -- x1 x2 ) pargs @
  dup tuple?  if  dup @ swap size integer  |  drop  0integer  0integer ;
: lookup_head  ( -- x1 x2 ) pargs @
  dup list? 0=  if  0integer  0integer  |
  car ?deref dup tuple?  if  dup @ swap size integer  |
  0integer ;
: switch  ( [lt ll la lo] -- ) r>  pargs @ deref dup pargs !
  dup tuple?  if  drop  @ >r  |
  dup list?  if  drop  cell+ @ >r  |
  atomic?  if  cell+ cell+  else  cell+ cell+ cell+  then  @ >r ;
: d=  ( x1 x2 y1 y2 -- f ) rot =  -rot =  and ;
: jumptable  ( x1 x2 [u atm1 atm2 addr ...] -- ) 
  r> @+ 3 cells * over + dup >r  swap  do
    2dup i @+ swap @ d=  if  
      2drop  i  unloop  r> drop  2 cells + @ >r  |
  3 cells +loop  2drop ;

\ child processes
variable >prevchild
: addchild  ( var pid -- ) morespace  \ 2 pairs
  integer swap make_list  %children @ make_list
  %children ! ;
: wakeup  ( status pid -- )
  >r  integer  %children dup >prevchild ! @  begin
    dup null? 0=  while
    dup car car get_int r@ =  if  ( status lst )
      <log  ." child process " r@ .  ." terminated with status "
        over write  cr  log>
      dup car cdr rot assign  cdr dup >prevchild @ !  r> drop  |
    list.tail dup >prevchild !  @
  repeat
  r>
  <log  ." unidentified child process terminated: "  dup .  cr  log>
  drop  2drop ;
: wait1  ( -- status pid | 0 )
  -1 WNOHANG waitpid 0<  if  2drop  0  |
  ?dup ?exit  2drop  0 ;
: (reap)
  [if-debug-build]
    <dlog  ." reaping child processes ..." cr  log>
  [then]
  begin  wait1 ?dup  while  wakeup  repeat ;
' (reap) is reap

: suspend_task  ( ctl -- )
  push  morespace  \ stream-pair + svar, use cdr of ctl as new svar
  pop cdr dup task task.svar !  dup task task.control !
  %suspend @ make_var  make_list  task task.status @
  swap assign  suspend ;
: resume_task  ( ctl -- )
  cdr dup  task task.control !
  task task.status @ ?deref dup list?  if
    cdr task task.status !
  else
    <err" status of resumed task is non-list"  .reason  ." : "  dwrite
    err>
  then ;
: check_control
  task task.control @ ?deref dup var?  if  drop  |
  dup remote?  if
    <err" task control stream may not refer to remote"
      .task  .reason  ." : "  dwrite  err>  |
  <dlog  .task  ." control: "  dup dwrite  cr  log>
  dup list?  if
    dup car deref %suspend @  ->  suspend_task  |
    \ checked on first process resumed on task.svar:
    %resume @  ->  resume_task  |
    <err" invalid task control object"  .task  .reason  ." : "  car dwrite  err>
  then
  task task.status @ swap assign ;
: (check_task)
  task %task0 @ = ?exit
  check_control
  task task.status @ ?deref dup var?  if  drop  |
  dup remote?  if
    <err" task status may not refer to remote"  .task  .reason  ." : " 
      dwrite  err>  |
  <dlog  .task  ." status: "  dup dwrite  cr  log>
  list?  if  task task.svar @ suspend  |
  schedule ; \ failed or stopped
' (check_task) is check_task

: (reclaimports)  #ports @ ?dup 0= ?exit
  gcreclaim  #ports @ >  if  schedule  then ;
' (reclaimports) is reclaimports

1 constant UNIDLED
: unidle  UNIDLED resumemark !
  %idlevar @ resume  resumemark off  make_var %idlevar !
  schedule ;
: (idleness) %idlevar @ var.deps @  if  unidle  then ;
' (idleness) is idleness
