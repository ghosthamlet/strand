\ Strand - library (builtin processes)

.( lib )

4 constant EINTR

: tohere  ( a -- a u ) dup here swap -  over h ! ;
: listlength  ( lst -- u ) 0 swap  
  begin  deref dup list?  while
    1 under+ cdr  repeat  
  drop ;
: badindex  ( u -- ) <err" index out of range"  .reason  ." : "  .  err> ;
: index  ( tup u -- a ) 2dup  swap size 0 swap within 0=
  if  1+  badindex  |  th ;
: cindex  ( b u -- a ) 2dup  swap octets 0 swap within 0=
  if  1+ badindex   |  + ;
: atomlength  ( atm -- u ) 0 swap bdata over +  
  begin 2dup <  while  swap utfdecode drop swap 
    rot 1+ -rot  repeat  
  2drop ;
variable %send_call
: check_ior  ( ior -- ) 0= ?exit  
  <err" error in system call"  .reason  ."  with error code "  errno ?  err> ;

\ builtins
: $reclaim/2  ( vf vt -- ) !var push  !var push
  gcreclaim  pop gcfree integer assign  pop gctotal integer assign ;
  0 builtin

: $events/1  ( v -- ) 
  !var %events_head @ assign  eventloop on
  %events_head off  ; 1 builtin
: $send/2  ( pix val -- ) ?deref  swap ?int send ; 2 builtin
: $send/3  ( pix val v -- ) !var -rot  $send/2  %[] @ assign ;
  3 builtin
: current_node/1  ( var -- ) !var self integer assign ; 4 builtin

: assignrem  ( x rem -- ) dropremote
  dup rem.var @ dup 0= abort" assigned remote has no variable"
  tuck mutate  swap assign ;  
: $assign_remote/3  ( id owner x -- ) 
  [if-debug-build]
    <dlog  ." assign_remote: " 3 writestack  log>
  [then]
  -rot swap ?int swap ?int  (findremote) \ assigns `id/owner`
  ?dup 0=  if  drop  <dlog  ." remote not found - ignored"  cr  log>  |
  dup remote?  if  assignrem  |  
  swap assign  id/owner 2@ dropref ; 5 builtin
: $get_exposed/2  ( id var -- ) 
  [if-debug-build]
    <dlog  ." get_exposed: " over write space  dup write cr  log>
  [then]
  swap ?int localremote assign ; 6 builtin

: $log/1  ( x -- ) deref*  <log  writelimit off  dup write  cr  log>  
  drop ; 7 builtin

: rcall  ( mid pdix -- ) >r  push morespace
  5 (make_tuple) %send_call @ over !  pop over 1 th !
  r> integer over 2 th !  pop over 3 th !  pop over 4 th !  add_event 
  terminate ;
: rcall_external  ( mname name arity -- ) 
  >r push resolve_module
  dup pop r> rot find_pdix  swap mod.id @ swap rcall ;
: $call_remote/4  ( mid|mname pidx|name tup node -- )
  <dlog  ." call_remote: " 4 writestack  log>
  push push  dup deref integer?  if  get_int  rcall  |
  top size rcall_external ; 8 builtin
: $call/3  ( mod pidx tup -- ) !tup push  ?int  swap !mod
  mod.pdefs @ swap th @ r> drop >r  pop 0 push_args ; 
  9 builtin
: $retrieve_module/3  ( mid nid var -- ) !var push  !int
  swap !str dup find_mid ?dup 0=  if  pop request_module  |
  pop swap assign  2drop ; 10 builtin
: $load_module/2  ( mid var -- ) !var push  !str  dup
  find_mid ?dup 0=  if  <err" module not found"  .reason  ." : "  write  err>  |
  nip  pop swap assign ; 11 builtin
: ?module  ( x -- mod )
  dup atom?  if  resolve_module  then  !mod ;
variable %/
: module_exports/2  ( mod var -- ) !var push  ?module
  mod.exports @ dup push size dup 2* cells ?heap \ roughly
  %[] @  swap  0  ?do
    top i 1+ th @  top i th @  %/ @  3 make_tuple  swap make_list
  3 +loop
  pop drop  pop swap assign ; 77 builtin
: $module_data/2  ( mod var -- ) !var push  ?module
  mod.mdef @  pop swap assign ; 104 builtin

: halt/1  ( i -- ) ?int  stopnode  
  <log  ." node terminated with exit code " dup .  cr  log>
  exitcode ; 12 builtin
: error/1  ( x -- ) deref* dup %failure !  
  \ fake <err" ... err>
  (<err)  [ here  0 , ]  write  [ here swap ! ]  (err>) ; 13 builtin

: write/1  ( x -- ) deref* write ; 14 builtin
: writeln/1  ( x -- ) write/1  cr ; 15 builtin
: writeln/2  ( x var -- ) !var  swap writeln/1  %[] @ assign ; 113 builtin

: bytelist  ( a u tail -- lst ) push  dup 4 * cells ?heap  \ N pairs
  tuck +  swap  0  ?do  
    1- dup c@ integer pop make_list push  loop
  drop  pop ;
: charlist  ( a u tail -- x ) push dup 4 * cells ?heap  \ N pairs
  here >r  over +  
  begin  2dup <  while
    swap utfdecode ,  swap  repeat  
  2drop  
  here dup r> - bytes  0  ?do  
    1 cells - dup @ integer pop make_list push  loop
  h !  pop ; 
32 k constant SAREA_OFF
variable >sarea
: sarea  ( -- a ) here SAREA_OFF + ;
: sreset  sarea >sarea ! ;
: sc,  ( c -- ) >sarea @ c!  1 >sarea +! ;
: sutfencode  ( u -- ) >sarea @ swap utfencode >sarea +!
  drop ;
: stringify  ( x -- a u ) >sarea @ >r
  begin  %[] @  ->  0 sc,  r> dup >sarea @ diff 1-  |
    !list @+ ?int sutfencode  @ deref
  again ;
: ?str  ( x -- a u ) deref dup atom?  if  bdata  |
  dup list? 0=  if  s" string or list" expected  |
  stringify ;
: ?strnull  ( x -- a|0 ) %[] @  ->  0  |  ?str drop ;
: ?stringish  ( x -- a u ) deref  dup bytes?  if  bdata  |  ?str ;

: string_to_list/3  ( s v x -- ) swap !var push  push
  !str bdata pop charlist  pop swap assign ; 16 builtin
: utflist_data ( lst -- a u ) deref*  here >r
  begin  deref %[] @  ->  r> tohere  |
    !list @+ ?int here swap utfencode allot drop  @  
  again ;
: list_to_string/2  ( lst v -- ) !var swap  utflist_data intern assign ;
  17 builtin

: make_tuple/2  ( i v -- ) !var push  ?int dup
  (make_tuple)  push  
  0  ?do  make_var top i th !  loop  
  pop  pop swap assign ; 18 builtin

variable ibase      10 ibase !
: stdbase  10 ibase !  decimal ;
: non_int  ( a u -- )
  <err" can not convert to integer"  .reason  ." : "  type  err> ;
: list_to_int/2  ( l v -- ) !var swap  !list  here >r  
  begin  
    deref %[] @  ->  r> tohere  
      ibase @ base !  number  stdbase  0=  if  non_int  |
      integer assign  |  
    dup car ?int c, cdr  
  again ; 19 builtin
: int_to_list  ( i v x -- ) swap !var push  push  ?int
  ibase @ base !  (.)  stdbase
  dup 4 cells * ?heap  tuck + 
  swap  0  do  
    1- dup c@ integer pop make_list push  loop  
  drop  pop pop swap assign ; 
: int_to_list/2  ( i v -- ) %[] @ int_to_list ; 20 builtin
: list_to_int/3  ( l i v -- ) rot deref* -rot 
  swap ?int ibase !  list_to_int/2 ; 37 builtin
: int_to_list/3  ( i1 i2 v -- ) rot deref -rot 
  swap ?int ibase !  int_to_list/2 ; 38 builtin
: int_to_list/4  ( i1 i2 v x -- ) push  rot deref -rot 
  swap ?int ibase !  pop int_to_list ; 128 builtin
variable ltmp
: list_to_tuple/2  ( lst var -- ) !var push
  deref dup null?  if  
    drop  0 (make_tuple) 
  else
    !list
    dup listlength swap push  dup 4 cells * ?heap
    dup (make_tuple) ltmp !  pop 
    swap  0  do  dup car ltmp @ i th !  cdr deref  loop
    ltmp @ then
  pop swap assign ; 21 builtin
: tuple_to_list/3  ( tup var x -- ) 
  swap !var push  swap !tup dup size >r
  push  push  r@ 4 cells * ?heap
  pop  pop  r@ th  
  r>  0  ?do  1 cells - dup @ rot make_list  swap  loop  
  drop  pop swap assign ; 22 builtin

: length/2  ( x v -- ) !var swap deref
  dup null?  if  drop  0integer assign  |
  dup atom?  if  atomlength integer assign |
  dup list?  if  listlength integer assign |  
  size integer assign ; 23 builtin

: run/2  ( mod x -- ) deref dup >r functor rot deref
  ?module find_export  r> swap >r 1 push_args ; 24 builtin
: get_module/2  ( atm var -- ) !var push  !str
  resolve_module pop swap assign ; 25 builtin
: newtask  task_drop  make_task %me @ process.task ! ;
: run/4  ( mod term svar ctl -- ) 
  2swap  deref push
  deref push  push  !var push  
  morespace  \ task (+ 2 vars)
  newtask  pop task task.status !  pop task task.control !
  <dlog  .task  ." created"  cr  log>
  pop ?module  pop dup >r functor rot find_export
  r> swap >r  1 push_args ; 69 builtin
: $run/5  ( mid pidx tup svar ctl -- )
  push  !var push  deref push  ?int >r  
  deref find_mid ?dup 0= abort" module not available"
  push  morespace  \ task (+ 2 vars)
  pop  newtask  pop  ( mod tup )
  pop task task.status !  pop task task.control !
  <dlog  .task  ." created"  cr  log>
  swap mod.pdefs @ r> th @ r> drop >r
  0 push_args ; 73 builtin

: assign/3  ( var1 x var2 -- ) !var push  
  swap !var swap assign  pop %[] @ assign ; 26 builtin

: put_arg/3  ( int tup x -- ) deref push  !tup  swap ?int 1-
  index @ pop assign ; 27 builtin
: put_arg/4  ( int tup x var -- ) !var push  put_arg/3  pop 
  %[] @ assign ; 28 builtin
: get_arg/3  ( int tup var -- ) !var push  !tup  swap ?int 1-
  index @ pop swap assign ; 29 builtin
: get_arg/4  ( int tup var1 var2 -- ) !var push  get_arg/3  pop
  %[] @ assign ; 30 builtin

: iomode  ( atm -- m ) bdata
  2dup s" rw" compare 0=  if  2drop  r/w  |
  2dup s" r" compare 0=  if  2drop r/o  |
  2dup s" w" compare 0=  if  2drop w/o  |
  2dup s" a" compare 0=  if  2drop a/o  |
  <err" invalid I/O mode"  .reason  ." : "  type err> ;
: open_file/3  ( atm dir var -- ) !var push  !str iomode swap 
  sreset dup >r ?str rot open-file  if  
    <err" error opening file"  .reason  ." : "  r> write  err>  |
  integer pop swap assign  r> drop ; 31 builtin
: close_file/1  ( fd -- ) ?int dup close-file  if  
    <err" error closing file"  .reason  ." : "  .  err>  |  drop ; 32 builtin
: readfailed  ( fd -- )
  errno @ EINTR =  if  drop  yield  |
  <err" error reading file"  .reason  ." : "  .  err> ;
: read_bytes/3  ( fd len var -- ) !var push
  ?int  >r  ?int dup here r> rot read-file  if  drop  readfailed  |
  nip  here swap make_bytes  pop swap  assign ; 33 builtin
variable wfd
: dowrite  ( a u -- ior ) 
  begin  2dup wfd @ write-file  0  ->  2drop  0  |
    errno @ EINTR <>  if  nip nip  |
  again ;
: fwritelist  ( lst -- ior ) here >r
  begin  %[] @  ->  r@ here r@ - dowrite  r> h !  |
    !list dup car ?int here swap utfencode allot drop  
    cdr deref  again ; 
: writefailed  ( fd -- )
  errno @ EINTR =  if  drop  yield  |
  <err" error writing file"  .reason  ." : "  .  err> ;
: write_chars/2  ( fd lst -- )  swap ?int wfd ! 
  deref fwritelist  if  wfd @ writefailed  then ; 34 builtin
: write/2  ( fd x -- )  deref* swap ?int  stdout @ >r stdout !
  write  r> stdout ! ; 35 builtin

\ merger: create merger process for each added merge(_) msg.
\ a destructively modified cell holds count of attached merger
\ processes. adding a value to a stream re-spawns a new merger
\ process.
variable %merge
\ chase tail of stream and assign
: assign_tail  ( str x -- ) swap  begin  
    ?deref dup var? 0=  while  
    %[] @  ->  
      <err" attempt to write into closed stream"  .reason  err>  |
    cdr
  repeat  
  swap  assign ;
: merger_close  ( str rcell -- )
  deref dup @ get_int  1  ->  drop  %[] @ assign_tail  |
  1- integer swap !  drop ;
: merge?  ( x -- f ) dup tuple? 0=  if  drop  false  |
  dup size 2 <>  if  drop  false  |  @ %merge @ = ;
defer merger1
\ mergeproc is called with args {str1, str2, rcell}
: mergeproc  %me @ process.args @ @+ swap @+ swap @ merger1 ;
: mkmerger  ( rcell str2 str1 -- ) 3 make_tuple
  ['] mergeproc >body make_process tuck process.args !  
  dup process.env off
  %merge @ over process.loc !  enqueue ;
: mergepush  ( str2 rcell str1 x -- ) 
  make_var dup >r make_list ( str2 rcell str1 str2' ) rot >r swap >r
  ( str2 str2' ) assign_tail  r> cdr  r>  r> ( str1' rcell str2' ) rot mkmerger ;
: addmerge  ( str2 rcell str1 str3 -- )
  push  push  deref 2 over +!  push  \ add 1 to refcount (fixnum)
  dup >r  pop dup >r  2nd  ( str2 rcell' str3 ) rot swap mkmerger
  pop cdr  r> r> ( str1' rcell' str2 ) rot  pop  drop mkmerger ;
: (merger1)  ( str1 str2 rcell -- ) 
  rot deref  %[] @  ->  merger_close  terminate |
  !list dup car dup merge?  if  task_drop  1 th @ addmerge  schedule  |  
  task_drop  mergepush  schedule ;
' (merger1) is merger1
: merger/2  ( str1 str2 -- ) push push  1 integer 1 make_tuple 
  pop pop swap mkmerger ; 36 builtin

: byte_length/2  ( x v -- i ) !var swap !block
  octets integer assign ; 39 builtin

: write/3  ( fd x v -- ) !var push  write/2  pop %[] @ assign ;
  40 builtin
: write_chars/3  ( fd lst var  -- ) !var push  write_chars/2  
  pop %[] @ assign ; 41 builtin

: string_to_byte_list/3  ( s v x -- ) swap !var push  push
  !str bdata pop bytelist  pop swap assign ; 42 builtin

: list2bytes  ( lst -- a ) here >r
  begin  %[] @  ->  r> tohere  |  !list dup car ?int c,  cdr deref  again ; 
: tobytes  ( x -- a u ) deref
  dup bytes?  if  bdata  |  dup atom?  if  bdata  |  list2bytes ;
: writebuf  ( a u -- ) wfd @ write-file  if  wfd @ writefailed  then ;
: write_bytes/5  ( fd x off cnt var -- )  !var push  ?int >r  ?int >r
  swap  ?int wfd !  tobytes  r> 1- /string  
  r@ swap >  if  r> badindex  |  r> writebuf 
  pop  %[] @  assign ; 43 builtin
: write_bytes/3  ( fd x var  -- ) !var push
  swap  ?int wfd !  tobytes  writebuf  pop %[] @ assign ; 44 builtin

variable firstarg       1 firstarg !       \ set in strand.f
: command_line/1  ( var -- ) !var push  #arg 1-  %[] @  
  begin
    over firstarg @ >=  while  
    over arg intern swap make_list  -1 under+
  repeat  
  nip  pop swap assign ; 45 builtin

: $resolve_peer/2  ( peer var -- ) !var push
  dup deref integer? 0=  if  !str resolve_peer  then  
  pop swap assign ; 46 builtin

: decode1  ( lst int -- lst' int' ) swap deref  %[] @  ->  %[] @ swap  |
  !list dup cdr swap car deref ?int 63 and  rot  6 lshift or ;
: decode  ( {v2 v1} lst int -- )
  dup 32 and  if
    dup 16 and  if
      7 and decode1 decode1 decode1
    else
      15 and decode1 decode1
    then
  else
    31 and decode1                       
  then
  integer pop swap assign  pop swap assign ;
: utf_decode/3  ( lst v1 v2 -- ) !var push  !var push
  !list dup cdr swap car ?int dup 128 and  if  decode  |
  integer  pop swap assign  pop swap assign ; 47 builtin
: utf_encode/3  ( i v x -- ) swap  !var push  push  ?int
  here swap utfencode pop bytelist  pop swap assign ;
  123 builtin 

: $register_peer/2  ( peer pidx -- ) !int swap  !str  swap
  add_peer ; 48 builtin
: current_node/2  ( var1 var2 -- ) !var node-id @ integer assign
  current_node/1 ; 49 builtin
: $add_reference/1  ( id -- ) ?int  self addref ; 
  50 builtin
: $drop_reference/1  ( id -- ) ?int  self dropref ;
  51 builtin

: listens  ( fdint -- var|0 )
  %listening @  
  begin  dup %[] @ <>  while
    2dup car car =  if  car cdr  nip nip  |
    cdr
  repeat  drop  0 ;
: listen/2  ( fd var -- ) 
  !var push !int  morespace
  dup listens ?dup  if  nip  pop swap assign  |
  pop make_list
[if-debug-build]
  <dlog  ." listen: " dup dwrite  cr  log>
[then]
  %listening @ make_list %listening ! 
  relisten on ; 52 builtin

: $forward/2  ( fd pack -- ) stdout @ >r  swap ?int stdout !
  !tup  here PORT_SIZE m-start
  <log  ." forwarding: " dup write  cr  log>
  here swap marshal  m-end  here - dup 1+ (.) tuck type  8 diff spaces
  here swap type  cr
  r> stdout ! ; 53 builtin
: readerr  <fatal  ." error while accepting forwarded message"  
  fatal> ;
: readfill  ( a u fd -- f ) >r 
  begin  ?dup  while
    2dup r@ read-file check_ior ?dup 0=  if  2drop  r> drop  false  |
    /string  repeat  r> 2drop  true ;
: readmsg  ( fd -- tup ) 
  >r  here 8 r@ readfill 0=  if  
    <log  ." EOF from remote peer"  cr  log>  stopnode  0 exitcode  |
  here 8 bl scan  nip 8 diff  here swap  number 0=  if  readerr  |
  ?dup 0=  if  <log  ." remote peer indicated end of communication"  cr
    log>  stopnode  0 exitcode  |
  PORT_SIZE ?heap
  here swap 2dup um-start  r> readfill 0=  if
    <fatal  ." unexpected end of input from remote peer"  fatal>  |
  here unmarshal nip  um-end ;
: $read_forwarded  ( fd var -- ) swap ?int readmsg assign ;
  64 builtin
: $deliver/1  ( msg -- ) !tup
  <log  ." delivering: " dup write  cr  log>
  dup 1 th @ bdata  rot @ get_int  send_data ; 54 builtin

: strand_version/1  ( var -- ) !var strand-version integer assign ;
  55 builtin

: '$randomize'/1  ( int var -- ) !var  swap ?int seed ! 
  random integer  assign ; 56 builtin

: $statistics/1  ( var -- ) !var push  morespace
  #proc integer  #spcount @ integer  #derefs @ integer
  #s-total @ integer  #r-total @ integer  sent @ integer
  #sent @ integer  received @ integer  #received @ integer
  #remotes @ integer  #exposed @ integer #atoms @ integer
  staticspace integer  13 make_tuple  pop swap assign ;
  57 builtin
: time/1  ( var -- ) !var time integer assign ; 75 builtin

: close_file/2  ( fd var -- ) !var swap  close_file/1
  %[] @ assign ; 58 builtin

variable %''        variable %os        variable %arch
: platform/2  ( var var -- ) !var %arch @ assign  
  !var %os @ assign ; 59 builtin
: getenv/2  ( str var -- ) !var  swap sreset ?str getenv
  ?dup  if  intern assign  |  %'' @ assign ; 60 builtin

: shell/2  ( str var -- ) !var  swap
  <log  ." spawning child process: "  dup dwrite  cr  log>
  sreset ?str
[defined] handle  [if]
  <fork  shell  fork>  nip nip addchild 
[else]
  system integer assign
[then] 
  ; 61 builtin
: open_pipe/2  ( var1 var2 -- ) !var swap  !var
  pipe check_ior  >r integer assign  r> integer assign ; 
  62 builtin
: redirect  ( fd1 fd2 -- ) 2dup =  if  2drop  |  (>[]) ;
: closelist  ( fdlst -- ) begin  dup %[] @ <>  while
    dup car ?int  close  cdr  
  repeat  drop ;
variable xargs
: execargs  ( lst -- a ) 
  dup @ ?str over c@ [char] / <>  if
    searchpath drop
  then
  here xargs !  sreset
  zstring ,  cdr
  begin  dup %[] @ <>  while
    dup car ?str drop ,  cdr 
  repeat  
  drop  0 ,  xargs @ ;
: !strlist  ( x -- x ) deref*  dup
  begin  dup %[] @ <>  while  !list dup  car !str/list drop  cdr  repeat
  drop ;
: $execute/7  ( lst svar fin fout ferr clst var -- )
  !var push  deref* push  ?int >r  ?int >r  ?int >r  !var >r 
  !list  !strlist
  <log  ." spawning child process: "  dup dwrite  cr  log>
  r>  r> r> r>  ( lst svar fin fout ferr )
  <fork  2 redirect  1 redirect  0 redirect
    drop  pop closelist
    execargs exec  <fatal  ." execve(2) failed" fatal>
    fork>  ( lst svar fin fout ferr pid )  pop drop  pop over integer assign
  >r  2drop  drop  r> addchild  drop ; 63 builtin

: file_size/2  ( str var -- )
  !var swap  sreset ?str r/o open-file check_ior dup file-size check_ior
  swap close  integer assign ; 65 builtin
: file_modification_time/2  ( str var -- )
  !var swap  sreset ?str r/o open-file check_ior dup file-mtime check_ior
  swap close  integer assign ; 66 builtin

: string_to_integer/2  ( str var -- )
  !var push  !str bdata  ibase @ base !  
  number  stdbase  0=  if  non_int  |
  integer  pop swap assign ; 67 builtin
: bstring_to_integer/3  ( str base var -- )
  swap ?int ibase !  string_to_integer/2 ; 68 builtin

: put_global/3  ( key val var -- ) !var push 
  swap !str put_global  pop %[] @ assign ; 70 builtin
: get_global/2  ( key var -- ) !var  swap !str dup >r get_global
  ?dup 0=  if  <err" global not found"  .reason  ." : "  r> dwrite  err>  |
  assign  r> drop ; 71 builtin
: get_global/3  ( key var def -- ) push  !var  swap !str get_global
  ?dup 0=  if  pop  then  assign ; 109 builtin

[defined] sys_pledge  [if]
: pledge/3  ( str1|[] str2|[] var -- ) !var >r
  sreset ?strnull  swap ?strnull  swap  sys_pledge syscall2 ior check_ior
  r> %[] @ assign ; 100 builtin
[else]
: pledge/3  !var >r  2deref  2drop  r> %[] @ assign ; 100 builtin
[then]
[defined] sys_unveil  [if]
: unveil/3  ( str1 str2 var -- ) !var >r
  sreset ?strnull  swap ?strnull  swap  sys_pledge syscall2 check_ior
  r> %[] @ assign ; 101 builtin
[else]
: unveil/3  !var >r  2deref  2drop  r> %[] @ assign ; 101 builtin
[then]
: set_user_id/2  ( id var -- ) !var  
  swap ?int sys_setuid syscall1 ior  check_ior
  %[] @ assign ; 102 builtin
: chdir/2  ( str var -- ) !var swap  sreset ?str chdir check_ior 
  %[] @ assign ; 72 builtin
: delete_file/2  ( str var -- ) !var swap ?str delete-file check_ior
  %[] @ assign ; 114 builtin
: kill/3  ( pid sig var -- ) !var -rot ?int swap ?int swap signal
  check_ior  %[] @ assign ; 115 builtin

61440 constant S_IFMT
16384 constant S_IFDIR      40960 constant S_IFLNK
variable %file      variable %directory     variable %link
variable %none
: file_status/2  ( str var -- ) !var  swap sreset ?str
  r/o open-file  if  
    drop  %none @  assign  |
  dup statbuf sys_fstat syscall2 drop  statbuf stat.mode + w@
  swap close
  S_IFMT and dup S_IFDIR =  if  drop  %directory @  assign  |
  S_IFLNK =  if  %link @  assign  |
  %file @  assign ; 74 builtin

: deref/2  ( x var -- ) !var  swap deref* drop  %[] @ assign ; 
  76 builtin

variable %send_assign_port
: open_port/2  ( var svar -- ) swap !var push  !var push  
  morespace
  pop make_var tuck var.val !  make_port  pop swap assign ;
  103 builtin
: (send_port)  ( lst x -- ) swap  
  begin  
    ?deref dup var? 0=  while
    dup list?  if   
      cdr  
    else  
      <err" port-stream contains non-list"  .reason  ." : "  dwrite  err>
    then
  repeat
  swap  assign ;
: !send_port  ( a x -- ) tuck  over @ swap (send_port)  ! ;
: send/2  ( port x -- ) deref push  !port push  morespace
  pop 
  <dlog  ." send to "  dup dwrite  ." : "  top dwrite  cr  log>
  port.cell @
  dup remote?  if  pop  swap dup rem.id @  swap rem.owner @
    %send_assign_port @  4 make_tuple  add_event  |
  var.val  pop make_var  make_list  !send_port ;
  105 builtin
: send/3  ( port x var -- ) !var push  send/2  pop %[] @ assign ;
  108 builtin
: $assign_port/2  ( id x -- ) push  morespace
  <dlog  ." remote send of "  top dwrite  ."  to "  dup .  cr  log>
  ?int localremote var.val  pop make_var  make_list
  !send_port ; 106 builtin

: $message_port_owner/2  ( addr var -- ) !var  swap 
  ?int localaddr >mport
  mport.owner @ integer  assign ; 112 builtin

: bytes_to_list/3  ( b v x -- ) swap !var push  push  !bytes bdata
  pop bytelist  pop swap assign ; 107 builtin
: list_to_bytes/2  ( lst v -- ) !var push  deref*  here >r
  begin  deref %[] @  ->  r> tohere make_bytes pop swap assign  |
    !list @+ ?int c,  @  
  again ; 110 builtin
: make_bytes/2  ( i v -- ) !var push  ?int (make_bytes) pop swap
  assign ; 111 builtin
: make_bytes/3  ( i1 i2 v -- ) !var push  ?int >r  ?int (make_bytes) 
  dup bdata r> fill  pop swap assign ; 122 builtin
: put_bytes  ( i b x -- ) deref* >r   !bytes swap ?int 1-
  r> dup integer?  if  get_int  -rot cindex c!  |
  dup binary?  if  
    >r  2dup cindex  -rot  r@ octets + 1- cindex drop
    r> bdata >r swap r> cmove  |
  begin  deref %[] @  ->  2drop  |  
    !list >r  2dup cindex r@ car ?int swap c!  1 under+  r> cdr
  again ; 
: $put_bytes/4  ( i b x v -- ) !var push  put_bytes  pop %[] @ assign ;
  116 builtin
: byterange  ( b i u1 -- a u2 ) >r  1- 2dup cindex  ( b i a1 )
  -rot  r> 1- + cindex  over - 1+ ;
: get_bytes/5  ( i1 b i2 v x -- ) push  !var push  ?int 
  ?dup 0=  if  pop  pop  assign  |  
  >r  !bytes  swap ?int r> byterange 2nd bytelist
  pop swap assign  pop drop ; 118 builtin
: copy_bytes/4  ( i1 b i2 var -- ) !var push  ?int 
  dup 0=  if  (make_bytes) pop swap assign  2drop  |
  >r  !bytes  swap ?int r> byterange make_bytes pop swap assign ;
  126 builtin
: char_list_to_bytes/2  ( lst v -- ) !var push  utflist_data make_bytes
  pop swap assign ; 132 builtin
: bytes_to_char_list/3  ( b v x -- ) swap  !var push  push  !bytes bdata
  pop charlist pop swap assign ; 133 builtin

begin-structure /itimerval
  field: interval.sec      field: interval.usec
  field: value.sec      field: value.usec
end-structure
0 constant ITIMER_REAL
/itimerval buffer: itimerval
: singleshot-timer  ( -- f ) itimerval interval.sec @+ swap @ or 0= ;
: (trigger-timer)  %timer @ ?dup 0= ?exit
  singleshot-timer  if  %[] @ assign  |
  clock @ integer  make_var dup >r  make_list  assign  r> %timer ! ;
' (trigger-timer) is trigger-timer
: sec/usec  ( u -- sec usec ) 1000 u/mod swap 1000 * ;
: set-timer  ( val interval -- ) sec/usec itimerval interval.usec !  
  itimerval interval.sec !  sec/usec itimerval value.usec !
  itimerval value.sec !   
  ITIMER_REAL itimerval 0  sys_setitimer syscall3 ior check_ior ;
: assign-timer  ( v -- ) push morespace
  make_var dup %timer !  pop swap assign ;
: timer/2  ( i v -- ) !var >r ?int  0  set-timer  r> assign-timer ; 119 builtin
: timer/3  ( i1 i2 v -- ) !var >r  ?int  swap ?int swap set-timer
  r> assign-timer ; 120 builtin
: disable_timer/0  0 0 set-timer  %timer @ %[] @ assign
  %timer off ; 121 builtin

: pack/2  ( x var -- ) !var push  pad unused m-start 
  pad swap marshal  m-end  pad - pad swap make_bytes  pop 
  swap assign ; 124 builtin
: unpack/2  ( bytes var -- ) !var push  !bytes bdata over >r um-start
  r> unmarshal  um-end  nip pop swap assign ; 125 builtin

: dereflist  ( lst -- u ) here swap
  begin  deref dup %[] @  <>  while
    !list dup push car !+  pop cdr  
  repeat  
  drop  here - bytes ;
: $$foreach  ( u lst -- ) r>  swap dereflist
  dup /process penv ?dup  if  octets  else  0  then  + 2 cells + * ?heap
  0  ?do  ( u ip ) 
    dup make_process dup enqueue
    dup process.env @ dup  if  copy  then  dup rot process.env !
    2 pick th  here i th @ swap !
  loop  
  terminate ; 127 builtin

: $inject_event/1  ( x -- ) 
  <dlog  ." inject: "  dup dwrite  cr  log>
  deref add_event ; 129 builtin

: getcwd/1  ( v -- ) !var  
  [defined] darwin  [if]        \ don't blame me
  pipe check_ior  <fork  >[]  s" pwd" shell  fork>  0 waitpid drop
  2drop drop  here 1024 rot dup >r read-file check_ior  drop 
  r> close-file drop
  [else]
  here 1024 sys_getcwd syscall2 ior check_ior 
  [then]
  here zcount intern  assign ; 131 builtin

: search_string/4  ( str1 str2 int var -- ) !var push  ?int  swap
  sreset  ?stringish  over >r  rot 1- /string
  rot ?stringish  search  if  drop r> - 1+ integer  pop swap  assign  |
  2drop  r> drop  pop  0integer  assign ; 134 builtin
: search_string/3  ( str1 str2 var -- ) 1 integer swap  search_string/4 ; 
  135 builtin
