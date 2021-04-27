\ Forth meta compiler for 32 bit ARM

\ Dictionary entry: [bits+len(1) name(?) pad(0-7) link(8) cfa(8) data(?)]

1 cells 4 <>  [if]  
  .( meta-compilation for 32-bit target needs 32 bit host ) bye
[then]

create meta

variable mbase            variable /codesegment
variable mbuf               variable mdp
h# 80 constant mi-bit       h# 40 constant ms-bit

: mreloc  ( a -- ma ) mbuf @ - mbase @ + ;
: munreloc  ( ma -- a ) mbase @ - mbuf @ + ;
: maddr  ( offset -- ma ) mbase @ + ;
: dvar  ( a -- ma ) /codesegment @ + maddr ;
: datasegment  ( -- ma ) /codesegment @ maddr ;
: /mbuffer  ( -- u ) here mbuf @ - ;
: mhead  ( | <word> -- ) bl word count 15 and 2dup type space
  tuck  here dup >r place  1+ allot  align
  mdp @ ?dup  if  mreloc  else  0  then  ,  r> mdp ! ;
: mlen  ( u1 -- u2 ) mi-bit ms-bit or invert and ;
: mcount  ( a -- a+1 u ) count mlen ;
: m>link  ( a1 -- a2 ) mcount + aligned ;
: m>cfa  ( a -- mxt ) m>link cell+ mreloc ;
: mcompare  ( a1 u a2 -- f ) count ( sic ) compare 0= ;
: mfind  ( a u -- a u 0 | mxt -1 ) mdp @ ?dup 0=  if  false  |
  begin >r 2dup r@ mcompare  if  2drop  r> m>cfa  true  |
  r> m>link @ ?dup  0=  if  false  |  munreloc  again ;
: mdist  ( from to -- n ) swap - ;
: msmudge  mdp @ dup c@ ms-bit or swap c! ;
: mreveal  mdp @ dup c@ ms-bit invert and swap c! ;
: mundefined  ( a u -- ) space  type  ."  ?"  abort ;
: (m')  ( a u -- mxt ) mfind 0=  if  mundefined  then ;
: [m']  ( | <word> -- mxt ) bl word count sliteral  postpone (m') ;
  immediate ;
: mliteral  ( x -- ) [m'] (lit) ,  , ;
: msliteral  ( a u -- ) [m'] (slit) ,  tuck here place 1+ allot  align ;
: m'  ( | <word> -- mxt ) bl word count (m') ;
: (mcompile)  ( a -- ) dup find 1 =  if  nip execute  |
  drop count mfind  if  ,  |  number  if  mliteral  |  mundefined ;
: mcompile  state on  begin  bl word  dup c@ 0=  if
    drop refill  else  (mcompile)  state @  then  while  repeat ;
: mwords  mdp @ ?dup 0= ?exit
  begin  mcount 2dup type space  + aligned @ ?dup  while  
  munreloc  repeat ;
: msave  ( | filename -- ) bl word count  2dup delete-file drop
  zstring w/o OPENX_MODE sys_open syscall3 dup ior ?ior
  >r  mbuf @ /mbuffer r@ write-file ?ior  r> close-file drop ;
: h!  ( x a -- ) >r  dup 255 and r@ c!  8 rshift r> 1+ c! ;
: h,  ( x -- ) here h!  2 allot ;
: w!  ( x a -- ) ! ;        : w,  ( x -- ) , ;

variable datasz
4 1024 * 1024 * constant heapsize   \ sic

include elf32.f
include addrs.f

: ]  ( | ... -- ) mcompile ;
: mvariable  ( | <word> -- ) mhead  '(variable) , ;
: create  ( | <word> -- ) mvariable ;
: constant  ( x | <word> -- ) mhead  '(constant) ,  , ;
: variable  ( | <word> -- ) mvariable  0 , ;
: buffer:  ( u | <word> -- ) mvariable  allot ;
: defer  ( | <word> -- ) mhead '(defer) ,  0 , ; \ no crash
: is  ( mxt | <word> -- ) m'  state @  if  mliteral  [m'] defer! ,  |
  munreloc cell+ ! ; immediate
: '  ( | <word> -- mxt ) m' ;
: begin  ( -- ) ( -- a ) here ; immediate
: again  ( -- ) ( a -- ) [m'] (else) ,  mreloc , ; immediate
: do  ( n1 n2 -- ) ( -- 0 a ) [m'] (do) ,  0  here ; immediate
: ?do  ( n1 n2 -- ) ( -- a1 a2 ) [m'] (?do) ,  here  0 ,  here ; 
  immediate
: loop  ( -- ) ( a1 a2 -- ) [m'] (loop) ,  mreloc ,  ?dup  if
  here mreloc swap !  then ; immediate
: +loop  ( n -- ) ( a1 a2 -- ) [m'] (+loop) ,  mreloc ,  ?dup  if
  here mreloc swap !  then ; immediate
\ subtle: no more uses of `if` after this:
: if  ( f -- ) ( -- a ) [m'] (if) ,  here  0 , ; immediate
: else  ( -- ) ( a1 -- a2 ) [m'] (else) ,  here  0 ,  here mreloc
  rot ! ; immediate
: then  ( -- ) ( a -- ) here mreloc swap ! ; immediate
: until  ( f -- ) ( a -- ) [m'] (if) ,  mreloc , ; immediate
: while  ( f -- ) ( a1 -- a1 a2 ) [m'] (if) ,  here  0 ,  ; immediate
: repeat  ( -- ) ( a1 a2 -- ) [m'] (else) ,  swap mreloc ,
  here mreloc swap ! ; immediate
: ->  ( x y -- | x ) ( -- a ) [m'] over ,  [m'] = ,  [m'] (if) ,  here 
  0 ,  [m'] drop , ; immediate
: |  ( -- ) ( a -- ) [m'] exit ,  here mreloc swap ! ; immediate
: abort"  ( f | ..." -- ) [char] " parse msliteral  [m'] (?abort) , ;
  immediate
: s"  ( | ..." -- a u ) [char] " parse msliteral ; immediate
: ."  ( | ..." -- ) [char] " parse msliteral  [m'] type , ; immediate
: [char]  ( | <char> -- c ) char mliteral ; immediate
: [']  ( | <word> -- mxt ) m' mliteral ; immediate
: kcode  ( ma | <word> -- ) mhead  , ;

\ subtle...
: (;) postpone ; ; immediate
: ;  [m'] exit ,  mreveal  state off  (;) immediate
: immediate  mdp @ dup c@ mi-bit or swap c! (;)
: :  ( | <word> -- ) mhead  msmudge  '(:)  ,  mcompile (;)

mdp off     align       here mbuf !
header
512 here mbuf @ - - allot   \ pad

.( including kernel code ... ) cr
include kernel.f
datasegment here mreloc - allot    \ pad
0 ,        \ args cell
0 ,        \ dp
0 ,        \ s0
0 ,        \ r0
0 ,        \ signals
0 ,        \ errno

.( compiling kernel headers ... ) cr
version 1+ constant version \ sic
include addrs.f
include words.f

cr .( compiling core ... ) cr
hex
18000 constant args
18004 constant dp
18008 constant s0
1800c constant r0
18010 constant signals
18014 constant errno
8000 constant imgbase
decimal
heapsize constant heapsize
create arm
include 32.f

cr .( patching variables ... ) cr
here mreloc datasegment - datasz @ !
hex
here mreloc dup .( h: ) .  m' h cell+ munreloc !
mdp @ mreloc dup .( dp: ) .  d# 4 dvar munreloc !
decimal
cr .( saving ) /mbuffer .  .( bytes ) cr
\ msave ff-*-*
