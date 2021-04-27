\ simple Cheney-style semispace GC

.( gc )

variable fspace-start   variable fspace-limit   variable fspace-top
variable tspace-start   variable tspace-limit   variable tspace-top
variable /space         variable scan-ptr

1 cells 1- constant unusedbits

24  1 cells 8 =  [if]  32 +  [then]  constant TAGSHIFT
: tagshift  ( u1 -- u2 ) TAGSHIFT lshift ;

hex
80 tagshift constant FWD_BIT
40 tagshift constant BYTE_BIT
0f tagshift constant TAG_MASK
f0 tagshift  constant BITS_MASK
0ff tagshift invert constant SIZE_MASK
decimal

variable gccount        variable nogc       variable gcalloced     
variable gcroots    variable #gcroots
defer gchook        defer gcscanhook
: addgcroot  ( x -- ) here  swap ,  gcroots @ ,  gcroots !  1 #gcroots +! ;
: >gcheader  ( a1 -- a2 ) 1 cells - ;
: gcheader  ( b -- x ) >gcheader @ ;
: tag  ( b -- tag ) gcheader TAG_MASK and ;
: bits  ( b -- bits ) gcheader BITS_MASK and ;
: binary?  ( b -- f ) gcheader BYTE_BIT and ;
: fwd?  ( b -- f ) gcheader FWD_BIT and ;
: octets  ( b -- u ) gcheader SIZE_MASK and ;
: bdata  ( b -- a u ) dup octets ;
: size  ( b -- u ) bdata  swap binary? 0=  if  bytes  then ;  
: available?  ( bytes -- f ) 
  cell+ aligned fspace-top @ + fspace-limit @ < ;
: forward  ( old-1 new-1 -- ) over @ !+  1 rshift FWD_BIT or 
  swap ! ;
: gctraceblock  ( old-1 size -- new )
  over tspace-top @ forward  >r 
  cell+ tspace-top @ cell+ r@ cmove 
  r> tspace-top @ cell+ dup >r + aligned tspace-top !  r> ;
: uablock?  ( a -- f ) unusedbits and ;
: gcblock?  ( a -- f ) dup uablock?  if  drop  false  |
  fspace-start @ fspace-limit @ within ;
: +inspace  ( a -- a | *a ) dup gcblock?  0=  if  r> drop  then ;
: unfwd  ( old -- new ) gcheader 1 lshift ;
defer gctraceroots      defer gctrace
: (gctrace)  ( old -- new )
  +inspace  dup fwd?  if  unfwd  | 
  dup 1 cells - swap octets gctraceblock ;  ' (gctrace) is gctrace
: gctrace!  ( a -- ) dup @ gctrace swap ! ;
: swapspaces
  tspace-start @  tspace-limit @
  fspace-start @ tspace-start !  tspace-top @ fspace-top !
  fspace-limit @ tspace-limit !
  fspace-limit !  fspace-start !  tspace-start @ tspace-top ! 
  1 gccount +! ;
: gcinit  ( addr size -- )  \ addr must be aligned
    2/ /space !  dup fspace-start !  
    /space @ + aligned dup fspace-limit !  dup tspace-start !
    /space @ + aligned tspace-limit !
    fspace-start @ fspace-top !
    tspace-start @ tspace-top !  
  gccount off  gcalloced off ;
: gctotal  ( -- u ) fspace-limit @ fspace-start @ - ;
: gcfree  ( -- u ) fspace-limit @ fspace-top @ - ;
: gcstart  tspace-top @ scan-ptr ! ;
: gcscan
    scan-ptr @ begin
\ dup 64 dump
        dup tspace-top @ <  while
        @+ dup BYTE_BIT and  if
            SIZE_MASK and + aligned
        else
            SIZE_MASK and bytes  0  ?do
                dup @ gctrace over ! cell+  loop
        then
    repeat drop ;

\ debugging variant of `gctrace`:
: gcvtrace  ( b -- b ) dup uablock? ?exit  
  dup tspace-start @ tspace-limit @ within  if
    <fatal  ." pointer to tospace: " cr  1 cells - 64 dump  fatal>  then
  +inspace  dup fwd?  if
    <fatal  ." pointer to forwarded block: " cr  dup 1 cells - 64 dump
    ." ->"  cr  unfwd 1 cells - 64 dump  fatal>  then ;

: gcreclaim  <log  ." GC start ... "  log>  gcstart  
<log ." trace " log>  \ XXX
  gctraceroots
<log ." roots " log>
  gcroots @  begin  ?dup  while  dup gctrace!  cell+ @  repeat
<log ." scan " log>
  gcscan  
<log ." hook " log> 
  gcscanhook
<log ." swap " log> 
    swapspaces  
  <log  ." ... GC done - free: "  gcfree dup .  ." used: " 
    gctotal diff .  cr  log>  gchook ;
: gcalloc  ( bytes -- a ) \ "a" points behind header
  dup available? 0=  if
    nogc @ ?dup  if  <fatal  ." GC in non-GC section "  .  fatal>  then
    gcreclaim  dup available? 0=  if  <fatal  ." out of heap"  fatal>  then
  then
  dup cell+ gcalloced +! 
  fspace-top @ 2dup + cell+ aligned fspace-top ! 
  2dup cell+ swap erase  swap !+ ;
: binary  ( b -- b* ) \ modifies header
  dup 1 cells - dup @ dup BYTE_BIT or or  swap ! ;
\ tags should have the form h# 0X00000000000000
: tagged  ( b tag -- b* ) \ modifies header
  over 1 cells - dup @ TAG_MASK invert and rot or swap ! ;

\ graph display
30 constant /bar
: barscale  ( max n1 -- n2 ) /bar * swap / ;
: .space  ( top limit start -- )
  dup (u.) type  ." →" 2dup - 3 pick rot  ( top limit total top start )
  - barscale dup >r [char] ▓ swap emits  ( top limit )
  swap u.  [char] ░ /bar r> - emits  ." ←"  u.  cr ;
: gcroom  ( -- )
  ."    From: "  fspace-top @ fspace-limit @ fspace-start @ .space
  ."      To: "  tspace-top @ tspace-limit @ tspace-start @ .space 
  2 spaces  gccount ? ." GCs, "   #gcroots ?  ." roots, "
  gcfree . ." bytes free of " gctotal . ;

\ tools
: every?:  ( b | ... -- f )
  r>  dup size 0  ?do  ( cb b ) 
    dup i th @ 2 pick callback  0=  if  unloop 2drop false  |
  loop  2drop  true ;
: foreach:  ( b | ... -- )
  r>  dup size 0  ?do  ( cb b ) dup i th @ 2 pick callback
  loop  2drop ;
: copy  ( b -- b' ) dup gcblock? 0= ?exit
  bdata 1 cells negate /string dup gcalloc dup >r swap cmove  r>  
  cell+ ;
: ?heap  ( u -- ) gcfree >=  if  gcreclaim  then ;
: morespace  256 ?heap ;
: gcstring  ( a u -- b ) dup gcalloc dup >r swap cmove
  r> binary ;
: conc  ( b1 a u -- b2 ) rot dup >r octets over + gcalloc ( a u b2 ) 
  dup r@ bdata rot swap cmove  dup r> octets + swap >r 
  swap cmove  r> ;
: xdump  ( x -- ) dup gcblock?  if  dup octets  swap 1 cells - 
    swap dump  |  h.  cr ;
