\ Strand - data objects

.( val )

h# 01 tagshift constant ATOM_TAG
h# 02 tagshift constant VAR_TAG
h# 03 tagshift constant TUPLE_TAG
h# 04 tagshift constant PROCESS_TAG
h# 05 tagshift constant MODULE_TAG
h# 06 tagshift constant LIST_TAG
h# 07 tagshift constant REMOTE_TAG
h# 08 tagshift constant BYTES_TAG
h# 09 tagshift constant PORT_TAG

MAXATOMS cells buffer: atoms 
atoms MAXATOMS cells erase
STATICBUF buffer: staticatoms
variable >staticatoms       staticatoms >staticatoms !
variable #atoms     variable #derefs
\ needed here for remote marshaling:
variable machine-id     variable node-id        
variable portx      -1 portx !
variable pclock
defer add_event  ( event -- )
variable %send_addref 
MAX_GLOBALS 2* cells buffer: globals       variable >globals
globals >globals !
variable %task0

defer write  ( x -- )       defer dwrite  ( x -- )

: self  ( -- u ) machine-id @ 8 lshift  portx @ or ;
: staticspace  ( -- u ) >staticatoms @ staticatoms - ;

\ https://en.wikipedia.org/wiki/Jenkins_hash_function
: hash  ( a u -- x )  0 -rot  0  ?do  
    count rot +  dup 10 lshift +  dup 6 rshift xor  swap  
  loop  drop  dup 3 lshift +  dup 11 rshift xor  dup 15 lshift + ;
: ?static  ( a -- ) staticatoms STATICBUF + >= 
  if  <fatal  ." string buffer overflow"  fatal>   then ;
: (astring)  ( a1 u a2 -- b ) dup >r swap cmove r>
  binary ATOM_TAG tagged ;
: sastring  ( a u -- b ) >staticatoms @ aligned dup >r 
  over + cell+ dup ?static >staticatoms !  r> over !+  (astring)
  0 >staticatoms @ tuck c!  1+ >staticatoms ! ;
: atom?  ( x -- f ) dup uablock?  if  drop  false  |
  staticatoms >staticatoms @ 1+ within ;  \ 1+ in case of null string
: addentry  ( a1 u a2 -- atm ) -rot sastring swap tuck ! @ 
  1 #atoms +!  ;
: wraparound  ( u -- a ) MAXATOMS cells 1- and  atoms + ;
: findentry  ( a1 u a2 -- atm ) begin  dup @ 0=  if  addentry  |  
    >r  2dup  r@ @ bdata compare 0=  if  2drop  r> @ |
    r> cell+ atoms -  wraparound  again ;
: intern  ( a u -- atm ) 2dup hash cells wraparound findentry ;
: .atoms  MAXATOMS  0  do  atoms i th @ ?dup  if  
    bdata type  space  then  loop ;

: valid?  ( x -- f ) dup uablock? ?exit  dup atom? ?exit
  fspace-start @ fspace-limit @ within ;

begin-structure /process
  field: process.ip     field: process.next     field: process.env
  field: process.args   field: process.id       field: process.loc
  field: process.task
end-structure
begin-structure /var
  field: var.val    field: var.deps      field: var.id
end-structure
begin-structure /remote
  field: rem.id     field: rem.owner    
  field: rem.var
end-structure
/var /remote <>  [if]  
  .( *** variable and remote differ in size ) abort  
[then]
begin-structure /list
  field: list.head     field: list.tail
end-structure
begin-structure /module
  field: mod.id     field: mod.name    field: mod.mdef     
  field: mod.exports    field: mod.pdefs
end-structure
begin-structure /task
  field: task.id    field: task.status  field: task.control
  field: task.svar  field: task.count
end-structure
begin-structure /port
  field: port.owner     field: port.id    field: port.cell
end-structure

variable %[]      variable %.
variable idcounter
: integer?  ( x -- f ) 1 and ;
: +block?  ( x -- x|0* ) dup gcblock? 0=  if  r> 2drop  false  then ;
: var?  ( x -- f ) +block?  tag VAR_TAG = ;
: module?  ( x -- f ) +block?  tag MODULE_TAG = ;
: tuple?  ( x -- f ) +block?  tag TUPLE_TAG = ;
: process?  ( x -- f ) +block?  tag PROCESS_TAG = ;
: atomic?  ( x -- f ) dup integer? ?exit  dup atom? ?exit  tuple? 0= ;
: null?  ( x -- f ) %[] @ = ;
: list?  ( x -- f ) +block?  tag LIST_TAG = ;
: bytes?  ( x -- f ) +block?  tag BYTES_TAG = ;
: port?  ( x -- f ) +block? tag PORT_TAG = ;
: remote?  ( x -- f ) +block?  tag REMOTE_TAG = ;
: +block  ( x -- x* ) dup gcblock? 0=  if  r> drop  then ;
: +var  ( x -- x* ) dup gcblock? 0=  if  r> drop  |
  dup tag VAR_TAG <>  if  r> drop  then ;
: deref?  ( x -- f ) 
  begin
    dup remote?  if  drop  false  |
    dup var? 0=  if  drop  true  |
    dup var.val @ 2dup =  if  2drop  false  |  
    nip 1 #derefs +!
  again ;
: ?deref  ( x -- x' ) dup remote? ?exit
  +var dup var.val @ 2dup =  if  drop  |
  nip 1 #derefs +!  recurse ;
: id  ( -- x ) idcounter @ dup  1+ idcounter ! ;
: car  ( lst -- x ) list.head @ ;
: cdr  ( lst -- x ) list.tail @ ;
: integer  ( n -- fx ) 1 lshift 1 or ;
0 integer constant 0integer
: get_int  ( int -- n ) 1 rshifta ;
: int+!  ( n a -- ) dup @ rot integer 1- + swap ! ;
: (make_tuple)  ( u -- t ) cells gcalloc TUPLE_TAG tagged ;
: make_tuple  ( ... u -- t ) dup (make_tuple)
  dup >r  swap  0  ?do  swap ?deref over i th !  loop   drop  r> ;
: make_tuple*  ( ... u -- t ) dup (make_tuple)  \ no implicit `?deref`
  dup >r  swap  0  ?do  swap over i th !  loop   drop  r> ;
: (make_bytes)  ( u -- b ) dup gcalloc binary  BYTES_TAG tagged ;
: make_bytes  ( a u -- b ) (make_bytes) dup >r swap cmove r> ;

: make_var  ( -- v ) /var gcalloc VAR_TAG tagged 
  id integer over var.id !  dup dup var.val ! ;
: make_list  ( hd tl -- lst ) ?deref  swap ?deref
  /list gcalloc LIST_TAG tagged  tuck list.head !  tuck list.tail ! ;
: unknown?  ( v -- f ) +block?  
  dup tag VAR_TAG <>  if  drop  false  |  dup var.val @ = ;
: make_remote  ( id owner -- rem ) /remote gcalloc 
  REMOTE_TAG tagged >r  integer r@ rem.owner !
  integer r@ rem.id !  r> ;

\ ports
variable >allports      variable >allports'
MAX_PORTVALS 2* cells buffer: allports
allports dup >allports !  MAX_PORTVALS cells + >allports' !
variable #ports
: (make_port)  ( rem/var -- b ) 
  /port gcalloc PORT_TAG tagged >r  id integer r@ port.id !
  self integer r@ port.owner !  r@ port.cell !  r> ;
: make_port ( rem/var -- b )
  #ports @ MAX_PORTVALS >=  if  <fatal  ." too many ports"  fatal>  |
  (make_port) dup >allports @ #ports @ th !  1 #ports +! ;

: (.task)  ( task -- ) ." ⊲" dup task.id @ get_int (.) type  ." :"  
  task.count @ get_int (.) type  ." ⊳" ;
: .process  ( p -- ) ." <process "  dup process.id @ get_int (.) type
  process.task @ dup %task0 @ <>  if  space  (.task)   else  drop  then
   ." >" ;

16 cells buffer: temps      
temps 16 cells + constant tempstop
variable >temps     
: tmpclear  temps >temps ! ;     tmpclear
: push  ( x -- ) 
  >temps @  [if-debug-build] 
    dup tempstop > abort" tempstack overflow"
  [then]
  swap !+ >temps ! ;
: pop  ( -- x ) -1 cells >temps +!  
  >temps @  [if-debug-build]
    dup temps < abort" tempstack underflow"
  [then]
  @ ;
: top  ( -- x ) >temps @ 1 cells - @ ;
: 2nd  ( -- x ) >temps @ 2 cells - @ ;

\ rbuckets: hash-table holding lists of "remote" records:
begin-structure /rrec
  field: rrec.id        field: rrec.owner
  field: rrec.obj      field: rrec.refcount
end-structure
\ If the `obj` is a variable,
\ then this is an exposed variable, otherwise it is a remote
\ reference. Exposed variables use the ref-count.
#RBUCKETS cells buffer: rbuckets
variable #remotes           variable #exposed
variable >rprev         variable %dropremotes
: initrbuckets  #RBUCKETS  0  do  %[]  @ rbuckets i th !  loop ;
: hashid  ( key -- u ) #RBUCKETS 1- and ;
: addremote  ( var id owner -- var ) 
  [if-debug-build]
    <dlog  ." register remote: "  over .  dup .  cr  log>
  [then]
  rot push  morespace  2dup xor >r  
  integer  swap integer  0integer  -rot  top -rot  ( 0 var owner id )
    4 make_tuple*
  rbuckets r> hashid th dup >r @ make_list r> !
  1 #remotes +!  pop ;  
2variable id/owner
: rrec=  ( tup -- f ) >r  id/owner 2@  r@ rrec.owner @ get_int =
  swap r> rrec.id @ get_int = and ;
: findremote0  ( id owner -- rrec|0 f ) 
  2dup id/owner 2!  xor hashid rbuckets swap th 
  dup >rprev !  @
  begin  dup %[] @ <>  while
    dup car rrec=  if  car  true  |
    list.tail dup >rprev ! @  
  repeat  
  drop  0  false ;
: (findremote)  ( id owner -- var|rem|0 ) 
  findremote0  if  rrec.obj @  then ;
: findremote  ( id owner -- var ) 2dup
  (findremote) ?dup 0=  if  
    <fatal  ." remote not found: "  swap  .  .  fatal>  
  then  nip nip ;
: expose  ( var -- id )  dup >r  
  var.id @ get_int dup self  (findremote)  if  r> drop  |
  r> swap self addremote var.id @ get_int
  1 #exposed +! ;
: localremote  ( id -- var ) self findremote ;
: addowner  ( rem -- ) dup rem.id @  swap rem.owner @ 
  %send_addref @  3 make_tuple  add_event ;
: external  ( owner id -- rem )
  swap 2dup (findremote) ?dup  if  
    [if-debug-build]
      <dlog  ." external remote: "  2 pick .  over .  cr  log>  
    [then]
    nip nip  |
  2dup make_remote -rot addremote  dup addowner ;
: newremote ( owner id -- var|rem)
  over self =  if  nip localremote  |  external ;
: dropremote  \ assumes `>rprev` is set
  [if-debug-build]
    <dlog  ." dropping remote: " >rprev @ @
      car dup rrec.id @ get_int .  rrec.owner @ get_int  .  cr  log>
  [then]
  >rprev @ dup @ cdr swap !  -1 #remotes +! ;
: addref  ( id owner -- ) 
  [if-debug-build]
    <dlog  ." addref: "  over .  dup .  cr  log>
  [then]
  findremote0 0=  if  
    <fatal  ." internal-error: exposed variable not found"  fatal>  |
  rrec.refcount dup @ get_int 1+ integer swap ! ;
: (dropref)  ( id owner -- )
  findremote0 0= if  
    <log  ." dropref: exposed not found - ignored"  cr log>  drop  |
  rrec.refcount dup @ get_int 1- tuck integer swap !
  0 <=  if  dropremote  -1 #exposed +!  then ;
variable >prevdrop
begin-structure /droprec
  field: droprec.pticks      field: droprec.id
  field: droprec.owner
end-structure
: dodrops  
  %dropremotes dup >prevdrop ! @  begin
    dup null? 0=  while
    dup car droprec.pticks @ get_int  pclock @ <  if
      dup car  dup droprec.id @ get_int  swap 
      droprec.owner @ get_int  (dropref)  
      cdr dup >prevdrop @ !
    else
      list.tail dup >prevdrop ! @
    then
  repeat 
  drop ;
: dropref  ( id owner -- )  \ add {idlecount, id, owner} tuple
  [if-debug-build]
    <dlog  ." scheduling for drop: "  over .  dup .  cr  log>
  [then]
  morespace \ list + 3-tuple
  integer  swap integer  pclock @ DROPPTICKS + integer  
  3 make_tuple %dropremotes @ make_list %dropremotes ! ;
: mutate  ( rem var -- ) 
  >gcheader swap  >gcheader /var cell+ cmove ;
: rem>var  ( rem -- var )
  \ locate remote to set `>rprev` for later dropping
  dup rem.id @ get_int  over rem.owner @ get_int findremote drop
  dropremote  dup rem.var @ ?dup 0=  if  make_var  then  
  tuck mutate ;

: gcval  
  #RBUCKETS  0  do  rbuckets i th gctrace!  loop
  >temps @  temps  ?do  i gctrace!  loop  
  >globals @  globals  ?do  i cell+ gctrace!  2 cells +loop
  %dropremotes gctrace! ;

: wlimit?  ( -- f )  writelimit @ 0=  if  false  |
  writecount @ writelimit @ >= ;
: +written  ( u -- ) writecount +! ;
: writelist  ( lst -- ) [char] [ emit  @+ write  @  
  begin 
    ?deref dup list?  while  
      @+  ." , "  write  @  wlimit?  if  drop  ." , ...]"  |  
  repeat
  dup null? 0=  if  [char] | emit  write  
  else  drop  then  [char] ] emit ;
: writentuple  ( tup -- ) dup size  swap @+ ?deref bdata type
  [char] ( emit  @+ write  swap  2  ?do  ." , "  @+ write  
    wlimit?  if  unloop  drop  ." , ...)"  |  loop
  drop  [char] ) emit ;
: writetuple  ( tup -- ) [char] { emit  dup @ write  dup size
  1  ?do  ." , "  dup i th @ write  wlimit?  if  unloop  drop  ." , ...}"  |
    loop  drop  [char] } emit ;
: writeblock  ( tup -- )
  dup @ ?deref %[] @ =  if  writetuple  |  
  dup size 1 =  if  writetuple  |  dup @ atom?  if  writentuple  |
  writetuple ;
: writevarid  ( x -- ) [char] _ emit  var.id @ get_int (.) type ;
: writevar  ( x -- ) dup var.val @ 2dup <>  if  nip  write  |
  drop  writevarid ;
: writeremote  ( x -- ) ." <remote "  dup rem.id @ get_int .
  rem.owner @ get_int (.) type  [char] > emit ;
: writebytes  ( x -- ) [char] # emit  base @ >r  hex
  bdata  0  ?do  
    count  dup 16 <  if  [char] 0 emit  then  
    (u.) type 
  loop  drop  r> base ! ;
: writeport  ( x -- ) ." <port "  dup port.owner @ get_int
  dup -1 =  if  drop  else  .  then  port.id @ get_int (.) type  ." >" ;
: (write)  ( x -- ) 1 +written
  ?deref ?dup 0=  if  ." <null>"  |
  dup integer?  if  get_int (.) type  |
  dup atom?  if  bdata type  |
  dup gcblock? 0=  if  ." <unknown "  (u.) type  ." >"  |
  dup var?  if  writevar  |
  dup port?  if  writeport  |
  dup remote?  if  writeremote  |
  dup module?  if  ." <module "  dup mod.name @ write  ." : "
    mod.id @ write  ." >"  |
  dup process?  if  .process  |  
  dup bytes?  if  writebytes  |
  dup size 0=  if  drop  ." {}"  |
  dup list?  if  writelist  |  writeblock ;  
' (write) is write

defer mcompile  ( mdef mid -- mod )

variable mlimit     variable watermark 
: mlimit!  ( a -- ) dup mlimit !  PORT_RESERVE - watermark ! ;
defer marshal  ( a1 x -- a2 )
: m-start  ( a u -- ) + mlimit!  1 nogc ! ;
: m-end  nogc off ;
: m-remaining  ( a -- u ) mlimit @ diff ;
: highwater?  ( a -- f ) watermark @ >= ;
: ?mbuf  ( a u -- ) + mlimit @ >  if
    <fatal  ." can not serialize - buffer full"  fatal>  then ;
: m-out  ( a1 c -- a2 ) over 1 ?mbuf  over c!  1+ ;
: m-outs  ( a1 a2 u -- a3 ) 0  ?do   count swap >r m-out  r>  loop 
  drop ;
: m-outn  ( a1 n -- a2 ) base @ >r  decimal  (.) m-outs  r> base !
  [char] : m-out ;
: m-var  ( a1 var -- a2 ) expose swap [char] R m-out
  swap m-outn  self m-outn ;
: m-placeholder  ( a1 x -- a2 ) make_var tuck var.val !
  m-var ;
: m-atom  ( a1 atm -- a2 ) 
  dup octets cell+ PORT_SIZE >=  if  
    <fatal  ." string of size "  dup octets .  ." exceeds serialization limit"
      fatal>  |
  2dup octets + highwater?  if  m-placeholder  |
  swap [char] $ m-out  over octets 
  m-outn  swap bdata m-outs ;
: m-bytes  ( a1 b -- a3 ) 
  dup octets cell+ PORT_SIZE >=  if  
    <fatal  ." bytes object of size "  dup octets .  
      ." exceeds serialization limit"  fatal>  |
  2dup octets + highwater?  if  m-placeholder  |
  swap [char] B m-out  over octets 
  m-outn  swap bdata m-outs ;
: m-list  ( a1 lst -- a2 ) 
  begin
    over highwater?  if  m-placeholder  |
    swap [char] . m-out  over car marshal  swap cdr ?deref
    dup list? 0=  if  marshal  |  
  again ;
: tuple~msize  ( tup -- u ) 
  \ estimate min serialization size (as tuple of remotes)
  size dup cells  swap 16 * + ;
: m-tuple  ( a1 tup -- a2 ) 
  dup tuple~msize dup PORT_SIZE >=  if  
    <fatal  ." tuple of size "  over size .  ." exceeds serialization limit"  
      fatal>  |
  2 pick + highwater?  if  m-placeholder  |
  swap [char] T m-out  over size m-outn
  over dup octets +  rot   ?do  i @  marshal  1 cells +loop ;
: m-mod  ( a1 mod -- a2 ) swap [char] M m-out  
  over mod.name @ marshal  over mod.id @ marshal  
  swap mod.mdef @ marshal ;
: m-remote  ( a1 rem -- a2 ) swap [char] R m-out
  swap dup >r rem.id @ get_int m-outn
  r> rem.owner @ get_int m-outn ;
: m-pack  ( a1 u -- a2 ) swap  [char] > m-out  swap m-outn ;
: m-port  ( a1 p -- a2 ) swap  [char] P m-out
  over port.owner @ get_int m-outn
  swap port.cell @
  dup remote?  if  m-remote  else  m-var  then ;
: m-int  ( a1 n -- a2 ) get_int
  dup 0 10 within  if  [char] 0 + m-out  |
  swap [char] I m-out  swap m-outn ;
: (marshal)  ( a1 x -- a2 ) ?deref  
  dup integer?  if  m-int  |
  dup atom?  if  m-atom  |
  dup bytes?  if  m-bytes  |
  dup gcblock? 0=  if  <fatal  ." can not serialize internal pointer"  fatal> |
  dup tag VAR_TAG  ->  m-var  |
  MODULE_TAG  ->  m-mod  |
  LIST_TAG  ->  m-list  |
  REMOTE_TAG  ->  m-remote  |
  PORT_TAG  ->  m-port  |
  TUPLE_TAG <>  if  <fatal  ." can not serialize unknown object"   fatal>  |
  m-tuple ;
' (marshal) is marshal

defer unmarshal  ( a1 -- a2 x )
2variable unmarshal_data
: um-start  ( a u -- ) unmarshal_data 2!  2 nogc ! ;
: um-end  nogc off ;
: um-inn  ( a1 -- a2 n ) dup 64 [char] : scan drop dup >r
  over - number  0=  if  <fatal  ." can not deserialize number"  fatal>  |
  r> 1+ swap ;
: um-ins  ( a1 u -- a2 a1 u ) 2dup + -rot ;
variable umtup
: um-tuple  ( a1 u -- a2 tup ) umtup @ >r  dup (make_tuple) umtup !
  0  ?do  unmarshal  umtup @ i th !  loop  umtup @  r> umtup ! ;
: um-mod  ( a1 -- a2 mod ) unmarshal push  unmarshal push  
  unmarshal pop  mcompile  pop over mod.name ! ;
: um-remote  ( a1 -- a2 rem ) um-inn swap um-inn rot  
  newremote ;
: um-skipln  ( a1 -- a2 )  begin  count  10 =  until ;
: um-remaining  ( a -- u ) unmarshal_data 2@  swap >r - r> diff ;
: um-pack  ( a1 u -- a2 p ) integer swap dup um-remaining
  over >r make_bytes  swap  2 make_tuple  r> swap ;
: um-bytes  ( a1 u -- a2 b ) um-ins make_bytes ;
: um-list  ( a1 -- a2 lst ) unmarshal %[] @ make_list dup push push
  begin  dup c@ [char] . =   while 
    1+ unmarshal %[] @ make_list dup pop list.tail !  push
  repeat  unmarshal pop list.tail !  pop ;
: um-port  ( a1 -- a2 port )  um-inn >r  unmarshal (make_port)
  r> integer over port.owner ! ;
: digit?  ( c -- f ) [char] 0 [char] : within ;
: (unmarshal)  ( a1 -- a2 x ) count
  dup digit?  if  [char] 0 - integer  |
  [char] I  ->  um-inn integer  |
  [char] $  ->  um-inn um-ins intern  |
  [char] T  ->  um-inn um-tuple  |
  [char] M  ->  um-mod  |
  [char] R  ->  um-remote  |
  [char] P  ->  um-port  |
  [char] .  ->  um-list  |
  [char] >  ->  um-inn um-pack  |
  [char] B  ->  um-inn um-bytes  |
  [char] #  ->  um-skipln  recurse  |
  13  ->  recurse  |  10  ->  recurse  |     
  <fatal  ." can not deserialize"  fatal> ;
' (unmarshal) is unmarshal

MAX_MODULES cells buffer: %mtable    variable #mtable
variable #exports       
: (find_module)  ( mname -- mod | atm 0 ) #mtable @  0  ?do
    dup  %mtable i th @ mod.name @ =  if  
      drop  %mtable i th @  unloop  |  loop  0 ;
: find_module  ( mname -- mod ) dup (find_module) ?dup ?exit
  <err" module not found"  .reason  ." : "  write  err> ;
: register_module  ( mod mid -- )
  over mod.id !  
  <log  ." registering module " dup mod.id @ write  cr  log>
  %mtable #mtable @ th !  1 #mtable +! ;
: (functor)  ( tup -- atm arity ) dup @  swap size 1- ;
: functor  ( x -- atm arity ) dup atom?  if  0  |
  dup tuple? 0=  if  
    <err" type error"  ." expected string or tuple: "  write  err>  |
  (functor) ;
variable findatm    variable findarity
: findx?  ( 2tup -- f ) dup gcblock? 0=  if  drop  false  |
  @+ findatm @ =  swap @ get_int findarity @ = and ;
variable findmdef
: find_pdix  ( atm arity mod -- pidx ) swap findarity !  
  swap findatm !  mod.mdef @ dup findmdef !
  size 2/  0  ?do  findmdef @ i 2* th @ findx?  if  
      i  unloop  |  loop  
  <err" process-definition not found"  .reason  ." : "  findatm @ write
    [char] / emit  findarity ?  err> ;
: (find_export)  ( atm arity mod -- ip|0 ) swap findarity !  
  swap findatm !
  mod.exports @  dup  size  0  ?do  
    dup i th @ findatm @ =  over i 1+ th @ get_int findarity @ =  and  if
      i 2 + th @  unloop  |
    3 +loop  drop  0 ;
: find_export  ( atm arity mod -- ip ) (find_export) ?dup ?exit
  <err" module-export not found"  .reason  ." : "  findatm @ write  
  [char] / emit  findarity ?  err> ;
variable fmid
: find_mid  ( mid -- mod|0 ) fmid !  
  #mtable @  0  ?do 
    %mtable i th @ dup mod.id @ fmid @ =  if  unloop  |
    drop  
  loop  0 ;

: put_global  ( val key -- ) 
  >globals @  globals  ?do  
    i @ over =  if  drop  i cell+ !  unloop  |
  2 cells +loop 
  >globals @ globals MAX_GLOBALS 2* cells + >=  if
    <fatal  ." too many globals"  fatal>  |
  >globals @ swap !+  swap !+  >globals ! ;
: get_global  ( key -- val|0 )
  >globals @  globals  ?do  
    i @ over =  if  drop  i cell+ @  unloop  |
  2 cells +loop  drop  0 ;

\ port-finalization
defer closeport  ( port -- )
: swapallports  >allports @  >allports' @ swap  >allports' !
  >allports ! ;
: portscanned  ( port --) unfwd  
  >allports' @  #ports @ th !  1 #ports +! ;
: streamtail  ( block -- tl dead? )
  true swap   begin  
    dup integer?  if  nip  true  |
    dup atom?  if  nip  true  |
    dup fwd?  if  nip  false swap  unfwd  then
    dup tag LIST_TAG =  if  cdr  else  swap  exit  then  
  again ;
: scanport  ( port -- )
  dup fwd?  if  portscanned  |
  dup port.cell @ dup fwd?  if  unfwd  then
  dup dup tag REMOTE_TAG =  if  2drop  |
  var.val @ streamtail  if  2drop  |
  [if-debug-build]
    <dlog  ." closing reclaimed port "  over h.  cr  log>
  [then]
  nip  closeport ;
: scanports 
  #ports @  #ports off  0  ?do  
    >allports @  i th @ scanport  
  loop  
  swapallports ;
' scanports is gcscanhook
