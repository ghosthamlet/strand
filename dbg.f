\ Strand - debugging tools

.( dbg ) 

: ??  %me @ write  space  %me @ process.args @ dwrite  space ;
: ???  ??  %me @ process.env @ dwrite  space ;
: ??.  ( x -- ) dup var? 0=  if  dwrite space  |
  [char] _ emit  dup var.id @ get_int .  dup var.val @ tuck =  if  
    drop  |  ." -> "  recurse ;
: lm  ( | filename -- ) bl word count intern load_module write ;
: (dwrite)  ( x -- ) writecount @ >r  writelimit @ >r
  LOGLIMIT limited  write 
  r> writelimit !  r> writecount ! ;
' (dwrite) is dwrite

variable nwrstack
: writestack  ( u -- ) dup nwrstack !  0  do  
    nwrstack @ i - 1- pick dwrite space  loop  cr ;

: .rtableentry  ( 3tup -- ) 4 spaces
  \ "<varid> / <owner> -> <var/remote> (<refcount>)"
  dup 0 th @ get_int .  ." / " dup 1 th @ get_int .  ." -> " 
  dup 2 th @ dwrite  ."  ("  3 th @ get_int (.) type  ." )"  cr ; 
: .rtablelist  ( lst -- )
  begin  %[] @  ->  |  dup car .rtableentry  cdr  again ;
variable rshown
: .rtable  rshown off  ."   remotes:" cr  
  #RBUCKETS  0  do  
    rbuckets i th @ dup %[] @ <>  if  
      .rtablelist  1 rshown +! 
    else  drop  then
    rshown @ 100 >  if  unloop  ."     :" cr  then
  loop 
  ."   remotes scheduled for drop: "  %dropremotes @ dwrite  cr ;

: .room  
  ."   node ID: " node-id ?  ."   machine ID: " machine-id ?
    ."   message-port is "  portx ?  cr
  2 spaces  #proc . ."  processes, " #suspended ?  
    ." suspended" cr 
  ."   clock: " clock ?
  ."  reductions: " #r-total ?  ."  suspensions: " #s-total ?
    ."  derefs: "  #derefs ?  cr
  ."   run time: " time starttime @ - .  ." sec  reductions/s: " r/s .  cr
  2 spaces  #remotes ?  ." remotes, "  #exposed ?  ." exposed"  cr
  ."   maximal number of processes: " #procmax ? cr
  ."   bytes sent: " sent ?  ." in " #sent ?  ." messages" 
    #sent/c @ ?dup  if  ."  ("  .  ." adjust)"  then  cr
  ."   bytes received: " received ?  ." in " #received ?  ." messages"
    #received/c @ ?dup  if  ."  ("  .  ." adjust)"  then  cr
  ."   GC heap:" cr  gcroom  cr
  ."   unused heap: " unused .  ."  string space: " staticspace  .  ." of "
  STATICBUF .  ." with " #atoms ?  ." interned" cr
  ."   unreclaimed ports: "  #ports ?  ."   peers: " %peers @ dwrite  cr 
  ."   listening: " %listening @ dwrite 
  %timer @ ?dup  if  ."   timer: "  dwrite  then  cr
  ."   events: " %events @ dwrite  ."   children: "  %children @ dwrite  cr
  ."   modules:"  cr  #mtable @  0  ?do  
    4 spaces  %mtable i th @ dwrite  cr  loop
 debugging @  if  .rtable  then ;

\ show value type distribution breakdown by going through
\ all live data in heap after GC:
variable varbytes   variable tupbytes   variable procbytes
variable listbytes   variable modbytes    variable rembytes
variable binbytes   variable portbytes
: bditem  ( size tag -- ) 
  VAR_TAG  ->  varbytes +!  |  TUPLE_TAG  ->  tupbytes +!  |
  PROCESS_TAG  ->  procbytes +!  |  PORT_TAG  ->  portbytes +!  |
  MODULE_TAG  -> modbytes +!  |  LIST_TAG  ->  listbytes +!  |
  REMOTE_TAG  ->  rembytes +!  |  BYTES_TAG  ->  binbytes +!  |
  2drop ;
: breakdown  varbytes off  tupbytes off  procbytes off
  listbytes off  modbytes off rembytes off  binbytes off
  portbytes off
  fspace-start @  begin  dup fspace-top @ <  while 
    dup @ dup SIZE_MASK and tuck swap TAG_MASK and  bditem  
    + cell+ aligned
  repeat  drop ;
: .breakdown  breakdown
  ." #$ "  clock ?  procbytes ?  tupbytes ?  listbytes ?  varbytes ?  
  rembytes ?  modbytes ?  binbytes ?  portbytes ?  cr ;

: (.stats)  statistics @ 1 and 0= ?exit
  <log  ." ## " clock ?  #proc dup .  #spcount @ dup . + .  
    #derefs ?  #s-total ?  #r-total ?
    sent ?  #sent ?  received ?  #received ?  
    #remotes ?  #exposed ?  #atoms ?  
    staticspace .  gcalloced ?  gctotal gcfree - .  cr  log> ;
' (.stats) is .stats
