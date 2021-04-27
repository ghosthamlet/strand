\ Strand - interprocess communication

.( ipc )

256 constant MAX_PORTS      
32 constant MIN_PORT

begin-structure /mport
  field: mport.lock   field: mport.owner      field: mport.size   
  PORT_SIZE 3 cells - +field mport.data
end-structure
2variable msgfile       variable msgbase    
variable msgport        variable eventloop
variable sent       variable received
variable #sent       variable #received
variable #sent/c       variable #received/c
variable %events       variable %events_head
variable %send_read     variable %send_get_module   
variable %send_value
variable %peers

: gcipc  %events gctrace!  %events_head gctrace! 
  %peers gctrace! ;
: addr>machine  ( addr -- mid ) 8 rshift ;
: addr>pix  ( addr -- pix ) 255 and ;
: .addr  ( addr -- ) dup addr>machine (.) type  [char] : emit  
  addr>pix . ;
: portdata  ( port -- a u ) dup mport.data swap mport.size @ ;
: tunneled?  ( addr -- f ) addr>machine  machine-id @ <> ;
: localaddr  ( addr -- pix ) 
  dup addr>machine  machine-id @  =  if
    addr>pix  
  else
    addr>machine  
  then ;
: >mport  ( pix -- port ) PORT_SIZE * msgbase @ + ;
[defined] cas  [if]
: trylock  ( port -- f ) mport.lock 1 0 rot cas ;
[else]
: trylock  ( port -- f ) mport.lock 1 lock? ;
[then]
\ add PAUSE x86 instruction here?
: lock  ( port -- ) begin  dup trylock 0=  while
    pause  repeat  drop  busy  ;
: unlock  ( port -- ) mport.lock off ;
: emptyport  ( port -- ) mport.size off ;
: unown  ( port -- ) mport.owner off ;
: setport  ( pix -- ) dup portx !  >mport dup msgport !  
  mport.owner node-id @ swap !  
  <log  ." message port index is "  portx ?  cr  log> ;
: portfull?  ( port -- f ) mport.size @ ;
: portempty?  ( port -- f ) mport.size @ 0= ;
: lockempty  ( port -- f ) \ return false on fail
  LOCK_ATTEMPTS swap  begin  over  while
    dup portempty?  if
      dup lock  dup portempty?  if  2drop  true  |
      dup unlock
    then 
    pause  -1 under+ 
  repeat 
  [if-debug-build]
    <dlog  ." too many lock-attempts - yielding ..."  cr  log>
  [then]
  2drop  busy  false ;
: claimport  node-id @ MAX_PORTS 1- and  
  dup MIN_PORT <  if  drop  MIN_PORT  then
  begin  
    dup >mport dup mport.owner @ 0=  if   ( pix port )
      dup lock  dup mport.owner @ 0=  if  swap setport  unlock  |
      unlock
    then  drop
    1+  MAX_PORTS 1- >  if  MIN_PORT  then again ;
: exitmsg  msgport @ ?dup  if  dup emptyport  unown  then ;
: nomsgfile 
  <log  ." can not open message-file: "  msgfile 2@ type  cr  
  log> ;
: initport  portx @ dup -1 <>  if  setport  
  else  drop  claimport  then ;
: openmsgfile  
  msgfile 2@ r/w map-file if  nomsgfile  |
  drop msgbase !  drop
  <log  ." node " node-id ?  ." opened message file " 
    msgfile 2@ type  ."  at "  msgbase ?  cr  log>
  initport ;
: initmsg  initrbuckets
  msgbase @ 0=  if  openmsgfile  |  
  <log  ." node " node-id ?  ." uses message file address " 
    msgbase ?  cr  log>
  initport ;
: initevents 
  make_var dup %events !  %events_head ! ;
: ?msg  msgbase @ 0=  if  
    <fatal  ." no message file open"  fatal>  then ;

: (add_event)  ( x -- ) 
  make_var dup >r make_list  %events @ swap assign  
  r> %events ! ;
' (add_event) is add_event

variable recvr      variable sleeping
: .recvr  recvr @ dup addr>machine (.) type  [char] : emit  
  addr>pix . ;
: .noowner  ." port has no owner: "  .recvr ;
: ?owner  ( port -- ) mport.owner @ 0=  if  <fatal  .noowner  fatal>  then ;

: .portdata  ( port -- )  recvr @ .addr ." <<"  portdata tuck type  ." >> "  . ;
: send  ( x addr -- ) ?msg  
  dup recvr !  localaddr  ( x pix )
  >mport dup ?owner  dup lockempty 0=  if  yield  |  ( x port )
  dup /mport m-start  dup mport.data dup >r   ( x port pdata )
  recvr @ tunneled?  if  recvr @ m-pack  then
  rot  marshal  m-end  r> - dup sent +!  over mport.size !   ( port )
  <log  .clock  ." sent to "  dup .portdata  cr  log>  unlock 
  1 #sent +! ;

\ special simplified case, used for $deliver/1
: dropmessage  stdout @ >r  errout  .noowner  ."  - message dropped"  cr  
  r> stdout ! ;
: send_data  ( a u locaddr -- ) 
  dup recvr !  addr>pix >mport
  dup mport.owner @ 0=  if  2drop  drop  dropmessage  |
  dup >r lockempty 0=  if  yield  |
  over sent +!
  tuck r@ mport.data swap cmove  r@ mport.size !  r>
  <log  .clock  ." sent forwarded data to "  dup .portdata  cr  log>  unlock ;

: (receive)  ( -- f ) 
  msgport @ dup trylock 0=  if  drop  false  |
  dup portfull? 0=  if  unlock  false  |  
  dup portdata
  <log  .clock  ." received on port "  portx ?  ." <<"  
    2dup type  ." >> "  dup .  cr  log> 
  dup received +!  dup cells ?heap
  um-start  dup mport.data unmarshal  um-end
  nip  add_event  dup emptyport  unlock  1 #received +! 
  true ;
: receive  msgport @ 0= ?exit  eventloop @ 0= ?exit
  sleeping off 
  begin (receive) ?exit  qempty?  while  
      pause  interrupts  idleness  0 poll_input 
      sleeping @ 0=  if  
        sleeping on  
        [if-debug-build]  <dlog  ." listening"  cr  log>  [then]
      then
  repeat  busy ;
' receive is msg_hook

: getremote  ( rem -- var ) 
  [if-debug-build]
    <dlog  ." getremote: " dup write  cr  log>
  [then]
  dup rem.var @ ?dup  if  nip  |
  push  morespace
  top rem.owner @  top rem.id @
  %send_read @ 3 make_tuple add_event
  make_var dup pop rem.var ! ;
' getremote is remoteref 
: setremote  ( x rem -- ) 
  [if-debug-build]
    <dlog  ." assigning "  over dwrite  ."  to remote "  
      dup write  cr  log>
  [then]
  dup rem.id @ >r  dup rem.owner @ >r
  swap push  rem>var  dup  top assign
  morespace  \ + var/list for event
  pop r> r> %send_value @  4 make_tuple add_event ;
' setremote is remoteassign

: request_module  ( nid mid var -- ) 
  push  push  >r  morespace  pop pop swap r> 
  %send_get_module @ 4 make_tuple add_event ;

: find_peer  ( name -- pidx|0 ) >r
  %peers @  begin  %[] @  ->  r> drop  0  |
    dup car dup car r@ =  if  r> drop  cdr  nip  |
    drop  cdr
  again ;
: resolve_peer  ( name -- pidx|var )
  dup find_peer ?dup  if  nip  |  
  <err" peer not found"  .reason  ." : "  dup dwrite  err> ;
: new_peer  ( peer idx -- )
  morespace  make_list  %peers @ make_list %peers ! ;
: add_peer  ( peer pidx -- ) >r  >r
  %peers @  begin  %[] @  ->  r> r> new_peer  |
    dup car dup car r@ =  if  r> drop  r> swap list.tail !  drop  |
    drop  cdr
  again ;
