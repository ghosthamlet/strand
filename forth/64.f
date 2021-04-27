\  64 bit core system
                                                                
0 constant false        -1 constant true                                                
32 constant bl                  

variable h                                

: unloop  r>  r> drop  r> drop  >r ;
: /  ( n1 n2 -- n3 ) /mod nip ;
: mod  ( n1 n2 -- n3 ) /mod drop ;
: u/  ( n1 n2 -- n3 ) u/mod nip ;
: umod  ( n1 n2 -- n3 ) u/mod drop ;
: depth  ( -- n ) s0 @ sp@ - 3 rshift 2 - ;                      
: 2nip  ( x y z q -- z q ) rot drop rot drop ;                  
: 2swap  ( x y z q -- z q x y ) rot >r rot r> ;                 
: 2over  ( x y z q -- x y z q x y ) 3 pick 3 pick ;             
: 2rot  ( x y u v p q -- u v p q x y ) >r >r 2swap r> r> 2swap ;                       
: clear  ( ... -- ) s0 @ sp! ;                                  
: signum  ( n1 -- n2 ) dup 0 >  if  drop 1  else  0<  then ;    
: within  ( n lo hi -- f ) over - >r - r> u< ;                  
: here  ( -- a ) h @ ;     
: allot  ( n -- ) h +! ;                                                        
: ,  ( n -- )  here !  1 cells allot ;                          
: c,  ( c -- ) here c! 1 allot ;                                
: pad  ( -- a ) here 256 + aligned ;                            
: align  ( -- ) here aligned h ! ;      
: k  ( n1 -- n2 ) 1024 * ;                        
: erase  ( a n -- ) 0 fill ;                                    
: blank  ( a n -- ) bl fill ;               
: ?exit  ( f -- ) if  r> drop  then ;
: under+  ( n1 x n2 -- n3 x ) rot + swap ;
: /string  ( a1 u1 n -- a2 u2 ) dup >r under+ r> - ;
: place  ( a1 u a2 -- ) 2dup >r >r 1+ swap cmove r> r> c! ;
: compare  ( a1 n1 a2 n2 -- n3 )
  rot 2dup >r >r min  0  ?do
    over i + c@ over i + c@ - signum ?dup  if
      nip nip  unloop  unloop  |  loop  2drop r> r> - signum ;
: -trailing  ( a u1 -- a u2 ) begin  1- dup 0<  if  1+  |  2dup + c@
    bl <>  until  1+ ;

: utfenc  ( a c -- a-1 c>>6 ) dup >r 63 and 128 or over c! 
  1- r> 6 rshift ;                                                                               
: utfencode  ( a c -- a n )                                 
  dup 128 <  if  over c!  1  |
  dup 2048 <  if  swap 1 + swap utfenc 192 or over c!  2  |
  dup 65536 <  if  swap 2 + swap utfenc utfenc 224 or over c!   3  |
  swap 3 + swap utfenc utfenc utfenc 240 or over c!  4 ;                              
: utfdec  ( a c -- a+1 c2 ) 6 lshift swap 1+ dup c@ 63 and rot  or ;
: utfdecode  ( a1 -- a2 c )                                     
  dup c@ dup 128 and  if                                        
    dup 32 and  if                                              
      dup 16 and  if                                            
        7 and utfdec utfdec utfdec                              
      else                                                      
        15 and utfdec utfdec                                    
      then                                                      
    else                                                        
      31 and utfdec                                             
    then                                                        
  then                                                          
  swap 1+ swap ;                                                

[defined] target-Linux  [if]
  [defined] target-aarch64  [if]
-100 constant AT_FDCWD
93 constant sys_exit        35 constant sys_unlinkat
63 constant sys_read       64 constant sys_write
56 constant sys_openat   57 constant sys_close
  [else]
    [defined] target-ppc64  [if]
1 constant sys_exit          10 constant sys_unlink
3 constant sys_read         4 constant sys_write
5 constant sys_open        6 constant sys_close
    [else]
60 constant sys_exit        87 constant sys_unlink
0 constant sys_read         1 constant sys_write
2 constant sys_open        3 constant sys_close
    [then]
  [then]
577 constant w/o               0 constant r/o
2 constant r/w                    1026 constant r/a
1089 constant a/o             512 constant O_TRUNC
create linux
[then]
[defined] target-OpenBSD  [if]
1 constant sys_exit           10 constant sys_unlink
3 constant sys_read         4 constant sys_write
5 constant sys_open        6 constant sys_close
1537 constant w/o            0 constant r/o
2 constant r/w                    10 constant r/a
521 constant a/o               1024 constant O_TRUNC
create openbsd
[then]
[defined] target-Darwin  [if]
h# 2000001 constant sys_exit   h# 200000a constant sys_unlink
h# 2000003 constant sys_read  h# 2000004 constant sys_write
h# 2000005 constant sys_open  h# 2000006 constant sys_close
1537 constant w/o            0 constant r/o
2 constant r/w                    10 constant r/a
521 constant a/o               1024 constant O_TRUNC
create darwin
[then]

420 constant OPEN_MODE
256 buffer: zpad            
: zstring  ( a1 u -- a2 ) zpad swap dup >r cmove  
  0 zpad r> + c!  zpad ;
: ior  ( n -- ior ) dup 0 >  if  drop  0  else
    [defined] target-Linux  [if]  dup negate errno !  [then]
  then ;
\ must check for aarch64, since definition of sys_openat is not visible to `[defined]`
\ during meta-compilation
[defined] target-aarch64  [if]
: open-file  ( a n fam -- fd ior ) 
  >r  AT_FDCWD -rot  zstring r> OPEN_MODE sys_openat syscall4 dup ior ;
: create-file  ( a n fam -- fd ior ) 
  >r  AT_FDCWD -rot  zstring r> O_TRUNC or  OPEN_MODE  sys_openat syscall4
  dup ior ;
[else]
: open-file  ( a n fam -- fd ior ) 
  >r zstring r> OPEN_MODE sys_open syscall3  dup ior ;
: create-file  ( a n fam -- fd ior ) 
  >r zstring r> O_TRUNC or  OPEN_MODE sys_open syscall3  dup ior ;
[then]
: close-file  ( fd -- ior ) sys_close syscall1 ior ;
: read-file  ( a u1 fd -- u2 ior ) -rot sys_read syscall3 dup ior ;
: write-file  ( a u fd -- ior ) -rot sys_write syscall3 ior ;
[defined] target-aarch64  [if]
: delete-file  ( a u -- ior ) AT_FDCWD -rot  zstring  0  sys_unlinkat syscall3 ior ;
[else]
: delete-file  ( a u -- ior ) zstring sys_unlink syscall1 ior ;
[then]

variable stdin      variable stdout     variable iobuf
variable eof
: (key)   ( -- c|0 ) eof off  stdin @  iobuf  1  sys_read syscall3  
  0=  if  eof on  0  |  iobuf c@ ;
: (type)  ( a u -- ) stdout @ -rot sys_write syscall3 drop ;

defer key     ' (key) is key
defer type    ' (type) is type

: emit  ( c -- ) iobuf swap utfencode type ;
: cr  ( -- ) 10 emit ;                                          
: space  ( -- ) bl emit ;                                       
: emits  ( c n -- ) begin  ?dup  while  over emit  1-  repeat  drop ;             
: spaces  ( n -- ) bl swap emits ;                              

create base 10 ,      variable >num                             
256 buffer: numbuf
: <#  numbuf 256 + >num ! ; 
: #  ( u1 -- u2 )  base @ u/mod swap dup 9 >  if  
    [char] a + 10 -  else [char] 0 +  then  >num @ 1- dup >num ! c! ;
: #s  ( u1 -- n2 ) begin  # dup  while  repeat ;                
: #>  ( u1 -- a n ) drop >num @ dup numbuf 256 + swap - ;                
: hold  ( c -- ) >num @ 1- dup >r c! r> >num ! ;                
: sign  ( n -- ) 0<  if  [char] - hold  then ;                  
: (u.)  ( u1 -- a u2 ) <# #s #> ;                               
: u.  ( u -- ) (u.) type space ;                                
: (.)  ( n1 -- a n2 ) dup abs <# #s swap sign #> ;              
: .  ( n -- ) (.) type space ;                                  
: u.r  ( n1 n2 -- ) >r <# #s #> r> over - 0 max spaces type ;   
: .r  ( n1 n2 -- ) >r dup abs <# #s swap sign #> r> over - 0    
  max spaces type ;              
: ?  ( a -- ) @ . ;                               
: .s  depth ?dup 0=  if  ." stack empty " |  
  dup 0  do  dup i - pick .  loop  drop ;

: hex  ( -- ) 16 base ! ;       : decimal  ( -- ) 10 base ! ;   
: (digit)  ( c -- n -1 | 0 0 )
  dup [char] A [char] [ within  if  55 -  true  |  \ 'Z' + 1        
  dup [char] a [char] { within  if  87 -  true  |  \ 'z' + 1        
  dup [char] 0 [char] : within  if  48 -  true  |  \ '9' + 1
  drop  0  false ;
: digit  ( c -- n -1 | 0 ) 
  (digit)  0=  ?exit  dup base @ <  if  true  else  drop  false  then ;
: numsign  ( a1 u1 -- a2 u2 n ) over c@ [char] -  =  if  1 /string -1  |  
  1 ;
: number  ( a n1 -- n2 -1 | a n1 0 )                            
  numsign >r  dup >r 0 swap 0  do  base @ * over i + c@ digit  
  0=  if  drop  unloop r> r> drop false  |  +  loop  r> drop nip r> *  true ;

variable >in        variable >limit     variable eval
1024 buffer: tib        64 buffer: wbuf 

: preserve  r>  eval @ >r  stdin @ >r  >in @ >r  >limit @  eval off  >r  >r ;
: restore  r>  r> >limit !  r> >in !  r> stdin !  r> eval !  eof off  >r ;
: limit?  ( -- f ) >in @ >limit @ >= ;                   
: getc  ( -- c ) >in @ c@  1 >in +! ;
: parsed  ( a2 -- a1 u ) >in @ over - ;
: parse  ( c | ... -- a u ) >in @ >r   begin  limit?  if  drop r> parsed |
    getc  10  ->  drop  r>  parsed  1-  |
    over =  if  drop r> parsed 1-  |  again ;
: ws?  ( c -- f ) bl  ->  true  |  13  ->  true  |  10  ->  true  |  9  ->  true
  |  drop  false ;
: skipws  begin  limit? ?exit  getc ws?  while  repeat  -1 >in +!  ;
: skipln  begin  limit? ?exit  getc 10 =  until ;
: wlen  ( u1 -- u2 ) 63 and ;
: significant  ( a u -- a u2 ) 31 and 15 min ;
: word  ( c | ... -- a ) skipws  parse wlen wbuf place  wbuf ;

: (accept)  ( a1 a2 c -- a3 a4 f )
  eof @  if  drop  true  |  10  ->  true  |  over c!  1+  false ;
: diff  ( n1 n2 -- n3 ) swap - ;
: accept  ( a u1 -- u2 ) over swap  begin  ?dup  while
    >r  key  (accept)  if  r> drop  diff  |  r> 1-  repeat  diff ;
: query  tib 1 k accept  tib + >limit !  tib >in ! ;
: refill  ( -- f ) eval @  if  false  |  query  true ;

variable context
: lookup  ( a u dp -- dp2 | 0 ) begin  ?dup  while
    >r  2dup r@ count 127 and compare 0=  if  2drop  r>  |
    r> count wlen + aligned @  repeat  2drop  false ;
: >cfa  ( dp -- xt ) count wlen + aligned cell+ ;
: >body  ( xt -- a ) cell+ ;
: >link  ( xt -- a ) 1 cells - ;
: (find)  ( a -- a 0 | xt 1 | xt -1 ) 
  dup count significant context @ @ 
  lookup ?dup  if  nip  dup c@ >r  >cfa  r> 
  128 and  if  1  else  -1  then  |  false ;

defer abort
: undefd  ( a u -- ) space  type  s"  ?" type  abort ;       
: bye  0 sys_exit syscall1 ;

defer find      ' (find) is find

variable warnings       variable current
: ?redef  ( a -- ) dup count significant current @ @ lookup  if  
    ."  redefined " count type space  |  drop ;
: head  ( | <word> -- ) bl word count  here >r  significant tuck here 
  place  1+ allot   warnings @  if  r@ ?redef  then  align
  current @ @ ,  r> current @ ! ;

: create  ( | <word> -- ) head  '(variable) , ;
: variable  ( | <word> -- ) create 0 , ;   
: '  ( | <word> -- xt ) bl word find 0=  if  count undefd  then ;
: buffer:  ( u | <word> -- ) create  allot ;
: constant  ( | <word> -- ) head '(constant) , , ;
: crash  ."  uninitialized execution vector"  abort ;
: defer  ( | <word> -- ) head '(defer) ,  ['] crash , ;
: immediate  current @ @ dup c@ 128 or swap c! ;
: literal  ( x -- ) ['] (lit) ,  , ;
: sliteral  ( a u -- ) ['] (slit) ,  tuck here place  1+ allot  align ;
: char  ( | <char> -- c ) bl word 1+ utfdecode nip ;
: "  ( | ..." -- a u ) [char] " parse >r  here r@ cmove  here r> dup allot ;
: defer!  ( xt a -- ) >body ! ;
: defer@  ( xt -- a ) >body @ ;

variable state      
: compword  ( xt ff -- )  1  ->  execute  |  drop  , ;
: compnum  ( a -- n ) count number  if  literal  else  undefd  then ;
: compile  ( a -- ) \ dup count type space
  find  ?dup  if  compword  else  compnum  then ;
: [  state off ; immediate
: ]  state on  begin  bl word dup c@ 0=  if  drop  refill  else
  compile  state @  then  0=  until ;
: smudge  current @ @ dup c@ 64 or swap c! ;
: reveal  current @ @ dup c@ 64 invert and swap c! ;
: :  ( | <word> -- ) head  smudge  '(:) ,  ] ;
: ;  ['] exit ,  state off  reveal ; immediate
: recurse  current @ @ >cfa , ; immediate
: <builds  ( | <word> -- ) head  '(does>) ,  0 , ;
: does>  ( a | ... -- ) r> current @ @ >cfa >body ! ;

: [char]  ( | <char> -- c ) char literal ; immediate
: [']  ( | <word> -- xt ) ' literal ; immediate
: (  ( | ... <paren> -- ) [char] ) parse 2drop ; immediate
: \  ( | ... -- ) eval @  if  skipln  |  >limit @ >in ! ; immediate
: s"  ( | ..." -- a u ) [char] " parse sliteral ; immediate
: ."  ( | ..." -- ) [char] " parse sliteral  ['] type , ; immediate
: postpone  ( | <word> -- ) bl word find dup 0=  if  count undefd  |
  1  ->  ,  |  drop  literal  ['] , , ; immediate
: (?abort)  ( f a u -- ) rot  if  space type  abort  |  2drop ;
: abort"  ( f | ..." -- ) [char] " parse sliteral  ['] (?abort) , ; immediate
: .(  ( | ... <paren> -- ) [char] ) parse type ; immediate
: begin  ( -- ) ( -- a ) here ; immediate
: again  ( -- ) ( a -- ) ['] (else) ,  , ; immediate
: until  ( f -- ) ( a -- ) ['] (if) ,  , ; immediate
: while  ( f -- ) ( a1 -- a1 a2 ) ['] (if) ,  here  0 , ; immediate
: repeat  ( -- ) ( a1 a2 -- ) ['] (else) ,  swap ,  here swap ! ; 
  immediate
: if  ( f -- ) ( -- a ) ['] (if) ,  here  0 , ; immediate
: else  ( -- ) ( a1 -- a2 ) ['] (else) ,  here  0 ,  here rot ! ; immediate
: then  ( -- ) ( a -- ) here swap ! ; immediate
: do  ( n1 n2 -- ) ( -- 0 a ) ['] (do) ,  0  here ; immediate
: ?do  ( n1 n2 -- ) ( -- a1 a2 ) ['] (?do) ,  here  0 ,  here ; immediate
: loop  ( -- ) ( a1 a2 -- ) ['] (loop) ,  ,  ?dup  if  here swap !  then ;
  immediate
: +loop  ( n -- ) ( a1 a2 -- ) ['] (+loop) ,  ,  ?dup  if  here swap !  
  then ; immediate
: ->  ( x y -- | x ) ( -- a ) ['] over ,  ['] = ,  ['] (if) ,  here  0 ,  ['] drop , ;
  immediate
: |  ( -- ) ( a -- ) ['] exit ,  here swap ! ; immediate
: is  ( xt | <word> -- ) '  state @  if  literal  ['] defer! ,  else  defer!  
  then ; immediate

: ?stack  sp@ s0 @ >=  abort" stack underflow" ;
: (interpret)  ( a -- ... ) find  if  execute  |  
  count number 0=  if  undefd then ;
: interpret  begin  bl word dup c@  while  (interpret)  repeat  
  drop  ?stack ;
: ?eof  eof @  if  ( ."  <eof>"  cr )  bye  then ;
: (prompt)  ."  ok"  cr ;
defer prompt        ' (prompt) is prompt
: quit  reset  clear  begin  query  ?eof  interpret  prompt  again ;
: forget  ( | <word> -- ) bl word dup c@ >r find 0=  if  count undefd
  then  >link dup @ current @ !  r> 1+ - h ! ;

: ?ior  ( ior -- ) dup 0<  abort"  I/O error "  drop ;
: evaluate  ( ... a u -- ... ) preserve  over >in !  + >limit !  eval on
  interpret  restore ;
: include-file  ( fd -- ) >limit @ >in !  preserve  stdin !  
  begin  query  interpret  eof @ until  restore ;
: included  ( a u -- ) r/o open-file ?ior  dup >r include-file
  r> close-file ?ior ;
: include  ( | <fname> -- ) bl word count included ;

: zcount  ( a -- a u ) dup  begin  dup c@  while  1+  repeat  
  over - ;
: #arg  ( -- u ) args @ @ ;
: arg  ( u1 -- a1 u2 ) 1+ cells args @ + @ zcount ;
: env  ( -- a ) args @ dup @ 2 + th ;
: env=  ( a1 u1 a2 -- f ) dup >r over dup >r compare 0=
  r> r> + c@  [char] = = and ;
variable envp
: getenv  ( a1 u1 -- a2 u2 | 0 )
  env envp !  begin  envp @ @ ?dup  while  
    >r  2dup  r@ env=  if  nip  r> + 1+ zcount  |
    r> drop  8 envp +!  repeat
  2drop  false ;
: stdio  0 stdin !  1 stdout !  eval off   eof off  ;
: (abort)  state off  decimal  stdio  cr  quit ;
: runargs  #arg  1  ?do  i arg evaluate  loop ;
: (startup)  runargs  (abort) ;
defer startup          ' (startup) is startup
' (abort) is abort

: forth  dp  dup current ! context !  ;
: cold  reset  clear  warnings on  stdio  forth  startup ;
