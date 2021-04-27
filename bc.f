\ Strand - bytecode-compiler

.( bc )

variable >pdefs         
variable >bcode        variable blimit
MAX_LIBPATH cells dup buffer: libpath  libpath swap erase
variable >libpath   
libpath MAX_LIBPATH th dup constant >libpathend >libpath !
MAX_BUILTINS cells dup buffer: builtins  builtins swap erase
: blip  <log  ." <blip> "  .s  cr  log> ;
variable bmid       \ must be static
: b-inn  ( -- n ) >bcode @ um-inn swap >bcode ! ;
: b-ins  ( u -- a u2 ) >bcode @ swap um-ins rot >bcode ! ;
: batom  ( -- atm ) b-inn b-ins intern ;
: bbuiltin  b-inn builtins swap th @ , ;
: builtin  ( u -- ) dp @ >cfa builtins rot dup >r th
  dup @  if  ."  builtin already in use: " r> .  abort  |
  !  r> drop ;
: b@+  ( -- u ) >bcode @ count swap >bcode ! ;
: binvalid  ( u -- )  <fatal  ." invalid bytecode: " .   fatal> ;
: bnative  ( a u -- ) here place  here find 0=  if  
  count undefd  then  , ;
variable >jumptable
: btable  ( u -- ) postpone jumptable  
  dup ,  here >jumptable !  3 * cells allot ;
: switch_tuple  ( a1 a2 u -- a1 a2 )
  >r  over here swap !   r>
  ?dup  if  postpone lookup_tuple  btable  then ;
: switch_list  ( a1 a2 -- a1 a2 ) 
  >r  over here swap cell+ !   r>
  ?dup  if  postpone lookup_head  btable  then ;
: switch_atomic  ( a1 a2 u -- a1 a2 ) 
  >r  over here swap cell+ cell+ !  r>
  ?dup  if  postpone lookup_arg  btable  then ;
: switch_other  ( a1 a2 -- a2 ) swap  4  0  do
    dup @ 0=  if  here over !  then  cell+  loop  drop ;
: bswitch  b@+  
  [char] s  ->  postpone switch  here swap  0 , 0 , 0 , 0 ,  |
  [char] t  ->  b-inn switch_tuple  |
  [char] l  ->  b-inn switch_list  |
  [char] a  ->  b-inn switch_atomic  |
  [char] o  ->  switch_other  |  binvalid ;
: bconst  ( -- x ) b@+  dup digit?  if  [char] 0 - integer  |
  [char] I  ->  b-inn integer  |
  [char] $  ->  batom  |  binvalid ;
: blabel  >jumptable @  bconst !+  bconst !+  
  here  !+  >jumptable ! ;
: bbytes  ( u -- ) ['] (bytes) ,  dup ,  0  ?do  b-inn c,  loop 
  align ;
: bgetarg  b-inn  0  ->  postpone getarg0  |  1  ->  postpone getarg1  |
  2  ->  postpone getarg2  |  3  ->  postpone getarg3  |  4  ->  postpone getarg4  |
  5  ->  postpone getarg5  |  6  ->  postpone getarg6  |  7  ->  postpone getarg7  |
  literal  postpone get_argument ;
: bgetenv  b-inn  0  ->  postpone getenv0  |  1  ->  postpone getenv1  |
  2  ->  postpone getenv2  |  3  ->  postpone getenv3  |  4  ->  postpone getenv4  |
  5  ->  postpone getenv5  |  6  ->  postpone getenv6  |  7  ->  postpone getenv7  |
  literal  postpone get_env ;
: bputenv  b-inn  0  ->  postpone putenv0  |  1  ->  postpone putenv1  |
  2  ->  postpone putenv2  |  3  ->  postpone putenv3  |  4  ->  postpone putenv4  |
  5  ->  postpone putenv5  |  6  ->  postpone putenv6  |  7  ->  postpone putenv7  |
  literal  postpone put_env ;
: bgcliteral  b-inn b-ins 2dup um-start  drop unmarshal nip
  um-end  postpone gcliteral  addgcroot ;
: bguard  b@+
  [char] `  ->  postpone =\=/2  |
  [char] <  ->  postpone </2  |
  [char] =  ->  postpone ==/2  |
  [char] >  ->  postpone >/2  |
  [char] a  ->  postpone @>/2  |
  [char] b  ->  postpone @</2  |
  [char] c  ->  postpone string/1  |
  [char] d  ->  postpone data/1  |
  [char] g  ->  postpone >=/2  |
  [char] h  ->  postpone @>=/2  |
  [char] i  ->  postpone integer/1  |
  [char] j  ->  postpone list/1  |
  [char] k  ->  postpone known/1  |
  [char] l  ->  postpone =</2  |
  [char] m  ->  postpone =:=/2  |
  [char] n  ->  postpone bytes/1  |
  [char] o  ->  postpone \=:=/2  |
  [char] p  ->  postpone  port/1  |
  [char] q  ->  postpone module/1  |
  [char] s  ->  postpone @=</2  |
  [char] t  ->  postpone tuple/1  |
  [char] u  ->  postpone unknown/1  |
  [char] z  ->  postpone idle/0  |
  binvalid ;
: bcomp1  b@+
  dup [char] 0  [char] :  within  if  [char] 0 - literal  |
  [char] !  ->  postpone assign  |
  [char] #  ->  postpone integer  |
  [char] |  ->  postpone ?int  |
  [char] $  ->  batom literal  |
  [char] %  ->  postpone match_null  |
  [char] &  ->  postpone abs  |
  [char] (  ->  postpone pfork  here  0 ,  |
  [char] )  ->  here swap !  |
  \ < = >
  [char] *  ->  postpone *  |
  [char] +  ->  postpone +  |
  [char] ,  ->  postpone %[]  postpone @  |
  [char] -  ->  postpone -  |
  [char] .  ->  postpone make_list  |
  [char] /  ->  postpone ?/  |
  [char] ;  ->  postpone tail_fork  |
  [char] ?  ->  postpone make_var  |
  [char] @  ->  blabel  |
  [char] A  ->  postpone arguments  |
  [char] B  ->  postpone make_tuple  |
  [char] C  -> postpone call_module  batom ,  batom ,  b-inn ,  |
  [char] D  ->  batom literal  postpone setloc  |
  [char] E  ->  bgetenv  |
  [char] F  ->  postpone module_ref  batom ,  batom ,  |
  [char] G  ->  bgetarg  |
  [char] H  ->  bmid @ literal  |
  [char] I  ->  b-inn literal  |
  [char] J  ->  b-inn  >pdefs @ swap th literal  postpone jump  |
  [char] K  ->  bbuiltin  |
  [char] L  ->  postpone match_list  |
  [char] M  ->  postpone match_var  |
  [char] N  ->  postpone match_tuple  |
  [char] O  ->  postpone drop  |
  [char] P  ->  bputenv  |
  [char] Q  ->  b-inn b-ins bnative  |
  [char] R  ->  b-inn bbytes  postpone match_bytes  |
  [char] S  ->  bswitch  |
  [char] T  ->  b-inn bbytes  postpone make_bytes  |
  [char] U  ->  postpone match_int  |
  [char] V  ->  postpone environment  |
  [char] W  ->  postpone max  |
  [char] X  ->  postpone terminate  |
  [char] Y  ->  bgcliteral  |
  [char] Z  ->  postpone mismatch  |
  [char] [  ->  postpone try  here 0 ,  |
  [char] \  ->  postpone ?mod  |
  [char] ]  ->  here swap !  postpone failed  |
  [char] ^  ->  postpone and  |
  [char] _  ->  postpone negate  |
  [char] g  ->  bguard  |
  \ a b c d h i j k l m n o q
  [char] e  ->  postpone clock  postpone @  |
  \ f  (used for example in HACKING)
  [char] p  ->  postpone remember  |
  [char] r  ->  postpone sqrt  |
  \ s t u
  [char] v  ->  postpone or  |
  [char] w  ->  postpone min  |
  [char] x  ->  postpone xor  |
  \ [char] y  (used for example in HACKING)
  [char] z  ->  b-inn integer literal  |
  [char] {  ->  postpone lshift  |
  [char] }  ->  postpone rshifta |
  [char] '  ->  ?dup  if  here swap !  then  postpone try  here 0 ,  |
  [char] ~  ->  postpone invert  |
  [char] "  ->  postpone blip  |     \ XXX
  10  ->  |  \ skip
  binvalid ;
: bcomp  ( a u -- ) 
  <dlog  ." compiling: " 2dup type ."  to " here .  cr  log>  
  bounds >bcode !  blimit ! 
  begin  >bcode @ blimit @ <  while  bcomp1  repeat 
  postpone exit ;    \ for `see`
: mkexports  ( mdef -- exps ) #exports off 
  dup push size dup cells ?heap
  2/  0  do  
    top i 2* th @ dup gcblock?  if  >pdefs @ i th @  
      swap @+ swap @ swap  1 #exports +!  
    else  drop  then  loop  
  #exports @ 3 * make_tuple  pop drop ;
: mcompile1  ( atm i -- ) 
   >pdefs @ swap th here swap !  bdata bcomp ;
: (mcompile)  ( mdef mid -- mod ) dup bmid !
  find_mid ?dup if  
    <dlog  ." module found: " bmid @ write  cr  log>  nip  |
  align  here >pdefs !  dup size 2/ dup 
  cells allot  0  do  dup i 2* 1+ th @ i mcompile1  loop
  dup push  mkexports push  /module gcalloc
  MODULE_TAG tagged pop over 
  mod.exports !  pop over mod.mdef !  >pdefs @ over mod.pdefs !
  dup bmid @ register_module ;
' (mcompile) is mcompile

: addlib  ( a u -- ) >libpath @ 1 cells - here over ! >libpath !  
  tuck here place  1+ allot ;
: tryopen  ( b -- fd -1 | b 0 ) dup bdata r/o open-file 0=  if
    <log  ." loading module "  over bdata type  cr  log>  nip  true  |
  drop  false ;
variable modatm
: findlib  ( atm -- fd|0 ) 
  modatm !  >libpath @  begin
    dup >libpathend >=  if 
      <err" module not found"  .reason  ." : "  modatm @ write  err>  |
    @+  1024 ?heap
    count gcstring s" /" conc modatm @ bdata conc dup >r
      MOD_EXTENSION conc tryopen  if  r> drop  nip  |
    drop  r> tryopen  if  nip  |  drop  again ;
variable modfd      variable provided
: compile_module  ( a atm -- mod ) >r
  dup bdata um-start  
  unmarshal swap unmarshal um-end  nip swap mcompile
  r> over mod.name ! ;
: read_mdata  ( fd -- a ) dup modfd !
  file-size ?ior  here swap modfd @ read-file ?ior  here swap allot 
  modfd @ close-file drop ;
: read_module  ( atm -- mod ) dup >r findlib read_mdata
  r> compile_module ;
: loaded_module  ( atm -- a|0 ) modatm !
  provided @  begin  ?dup  while  
    @+ modatm @ =  if  @  |  cell+ @  repeat  false ;
: -extension  ( atm -- atm' ) MOD_EXTENSION nip >r
  dup bdata dup r@ - /string  ( atm a u )
  MOD_EXTENSION compare 0=  if  bdata r> - intern  |
  r> drop ;
: load_module  ( atm -- mod ) -extension
  dup loaded_module ?dup  if
    <log  ." loading hardwired module "  over write  cr  log>
    swap compile_module  |  read_module ;
: (resolve_module)  ( mname -- mod )
  (find_module) ?dup ?exit  load_module ;
' (resolve_module) is resolve_module
: include_module  ( | name fname -- )
  bl word count intern dup bdata type space  >r  bl word count 
  r/o open-file ?ior read_mdata  here r> ,  swap ,  provided @ ,  
  provided ! ;
: load_main  s" main" intern dup loaded_module  if  
    load_module  then  drop ;
