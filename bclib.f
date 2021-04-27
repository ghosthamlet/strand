\ Strand - library (for bytecode compiler)

.( bclib )

: expected  ( x a u -- ) <err" type error"  ." expected "  type  ." : "  
  dwrite  err> ;
: 2deref  ( x y -- x' y' ) swap deref  swap deref ;
: !int  ( x -- int ) deref
  dup integer? 0=  if  s" integer" expected  then ;
: ?int  ( x -- i ) !int get_int ;
: 2int  ( x y -- int1 int2 ) swap !int  swap !int ;
: !var  ( x -- x ) dup remote? ?exit
  dup var? 0=  if  s" variable" expected  |
  dup var.val @ over <>  if  s" variable" expected  then ;
: !str  ( x -- x ) deref dup atom? 0=  if  s" string" expected  then ;
: !list  ( x -- x ) deref dup list? 0=  if  s" list" expected  then ;
: !str/list  ( x -- x ) deref dup atom? ?exit  dup list? ?exit
  s" string or list" expected ;
: exp_tuple  ( x f -- )  if  s" tuple" expected  then ;
: !block  ( x -- x ) deref dup gcblock? ?exit
  dup atom? 0= if  s" block" expected  then ;
: !tup  ( x -- x ) deref dup tuple? 0=  exp_tuple ;
: exp_mod  ( x f -- )  if  s" module" expected  then ;
: !mod  ( x -- x ) deref dup list? exp_mod
  dup module? 0= exp_mod ;
: !bytes  ( x -- x ) deref dup bytes? 0=  if  s" bytes" expected  then ;
: !port  ( x -- x ) deref dup port? 0=  if  s" port" expected  then ;
: val=?  ( x y -- f ) ?deref  swap ?deref 2dup =  if  drop  |
  2deref  2dup =  if  drop  |
  dup gcblock? 0=  if  2drop  false  |
  over gcblock? 0=  if  2drop  false  |
  over tag over tag <>  if  2drop  false  |
  over octets over octets <>  if  2drop  false  |
  dup binary?  if  2drop  false  |
  dup size  0  ?do  @+  rot @+ rot recurse 0=  if  unloop  2drop  false  |
  loop  2drop  true ;
: val<>?  ( x y -- f ) ?deref  swap ?deref 2dup =  if  2drop  false  |
  2deref  2dup =  if  2drop  false  |
  dup gcblock? 0=  if  2drop  true  |
  over gcblock? 0=  if  2drop  true  |
  over tag over tag <>  if  drop  |
  over octets over octets <>  if  drop  |
  dup binary?  if  2drop  false  |
  dup size  0  ?do  @+  rot @+ rot recurse  if  unloop  drop  |
  loop  2drop  false ;
: push_args  ( tup start -- ... ) 
  over size  swap  ?do  dup i th @ swap  loop  drop ;
: ?div/0 ( n -- n ) dup 0=  if  
    <err" division by zero"  .reason  err>  then ;
: ?/  ( n1 n2 -- n ) ?div/0 / ;
: ?mod  ( n1 n2 -- n ) ?div/0 mod ;

\ https://stackoverflow.com/questions/1100090/looking-for-an-efficient-integer-square-root-algorithm-for-arm-thumb2
variable op     variable res
: sqrt  ( u1 -- u2 ) op !  res off  1 1 cells 8 * 2 - lshift
  begin  dup op @ >  while  2 rshift  repeat
  begin  ?dup  while  ( one )
    dup res @ + op @ over >=  if  ( one res+one )
      dup op @ diff op !
      over + res !  
    else  drop  then
    res @ 2/ res !  2 rshift 
  repeat  res @ ;

\ guards
: ==/2  ( x y -- ) val<>? ?mismatch ;
: =\=/2  ( x y -- ) val=? ?mismatch ;
: =:=/2  ( x y -- ) <> ?mismatch ;
: \=:=/2  ( x y -- ) = ?mismatch ;
: </2  ( x y -- ) >= ?mismatch ;
: >/2  ( x y -- ) <= ?mismatch ;
: =</2  ( x y -- ) > ?mismatch ;
: >=/2  ( x y -- ) < ?mismatch ;
: known/1  ( x -- ) deref? 0=  ?mismatch ;
: unknown/1  ( x -- ) deref?  ?mismatch ;
: data/1  ( x -- ) deref drop ;
: string/1  ( x -- ) deref  %[] @  ->  mismatch  |
  dup atom?  if  drop  |  mismatch ;
: tuple/1  ( x -- ) deref dup gcblock? 0= ?mismatch  
  tag TUPLE_TAG <> ?mismatch ;
: integer/1  ( x -- ) deref integer? 0= ?mismatch ;
: list/1  ( x -- ) deref  dup gcblock? 0= ?mismatch  tag 
  LIST_TAG <> ?mismatch ;
: module/1  ( x -- ) deref module? 0= ?mismatch ;
: port/1  ( x -- ) deref port? 0= ?mismatch ;
: idle/0  %me @ process.next @ UNIDLED =  if
    %me @ process.next off  |  %idlevar @ suspend ;
: bytes/1  ( x -- ) deref  bytes? 0= ?mismatch ;

\ matching
: match_null  ( x -- ) deref  %[] @ <> ?mismatch ;
: match_list  ( x -- tl hd ) deref dup gcblock? 0= ?mismatch
  dup tag LIST_TAG <> ?mismatch  dup cdr  swap car ;
: match_tuple  ( x u -- y ... ) >r  deref dup tuple/1 
  dup size r@ <> ?mismatch  r@ th  r>  0  ?do
    1 cells -  dup @ swap  loop  drop ;
: match_var  ( x u -- ) get_env ==/2 ;
: match_int  ( x n -- ) integer ==/2 ;
: match_bytes  ( x a u -- ) rot deref dup bytes? 0= ?mismatch
  bdata compare ?mismatch ;
: (bytes)  ( [u ...] -- a u ) r> @+  2dup + aligned >r ;

\ ordered comparison guards
defer order
: typeorder  ( x -- u ) dup integer?  if  drop  1  |
  %[] @  ->  2  |  dup atom?  if  drop  2  |
  dup gcblock? 0=  if  drop  7  |  dup list?  if  drop  3  |  
  dup tuple?  if  drop  4  |
  dup port?  if  drop  5  |  module?  if  6  |  7 ;
: stringorder  ( x y -- n ) over octets dup >r over octets dup >r
  min  0  ?do  
    over i + c@  over i + c@ - ?dup  if  
      unloop  nip nip  r> r> 2drop  |
  loop  2drop r> r> swap - ;
: tupleorder  ( x y -- n ) 
  over size over size - ?dup  if  nip nip  |
  dup size  0  ?do  
    over i th @  over i th @ order ?dup  if  unloop  nip nip  |
  loop  2drop  0 ;
: listorder  ( x y -- n )
  over car over car order ?dup  if  nip  nip  |
  cdr swap cdr swap order ;
: (order)  ( x y -- n ) 2deref
  over typeorder over typeorder  
  - ?dup ?exit  2dup =  if  2drop  0  |  dup integer?  if  -  |  
  %[] @  ->  drop  1  |  over %[] @  ->  2drop  -1  |  drop
  dup atom?  if  stringorder  |  dup gcblock? 0=  if  -  |  
  dup bytes?  if  stringorder  |
  dup port?  if  swap port.id @  swap port.id @ -  |
  dup module?  if  swap mod.id @  swap mod.id @ stringorder  |
  dup list? >r over list? r> and  if  listorder  |  
  tupleorder ;
' (order) is order
: @>/2  ( x y -- ) order 0 <= ?mismatch ;
: @</2  ( x y -- ) order 0 >= ?mismatch ;
: @>=/2  ( x y -- ) order 0 < ?mismatch ;
: @=</2  ( x y -- ) order 0 > ?mismatch ;
