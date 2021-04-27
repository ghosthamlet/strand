\ tools + extensions

create tools

\ misc
: bounds  ( a1 n -- a2 a1 ) over + swap ;
: (d/h#)  ( b | <num> -- x ) bl word count number
  0= abort" bad number syntax"  state @  if  literal  else  
  swap  then  base ! ;
: h#  ( | <num> -- x ) base @  hex  (d/h#) ; immediate
: d#  ( | <num> -- x ) base @  decimal  (d/h#) ; immediate
: h.  ( u -- ) base @  swap  hex  u.  base ! ;
: noop ;
: member  ( x a1 u -- a2|0 )  0  do  
    2dup @ =  if  unloop  nip  |  cell+  loop  2drop  0 ;
: scan  ( a1 u1 c -- a2 u2 ) >r begin 
    dup 0=  if  r> drop  |  over c@ r@ <>  while  1 /string
   repeat  r> drop ;
: skip  ( a1 u1 c -- a2 u2 )  >r begin 
    dup 0=  if  r> drop  |  over c@ r@ =  while  1 /string
    repeat  r> drop ;
: split  ( a1 u1 c -- a2 u2 a1 u3 ) >r 2dup r> scan 2swap 2 pick - ;
: string,  ( a u -- ) here over 1+ allot place ;                
: ,"  ( | ..." -- ) [char] " parse string, ;              
: 2@  ( a -- x y ) dup cell+ @ swap @ ;
: 2!  ( x y a -- ) swap over ! cell+ ! ;
: 2>r  ( x y -- ) r> -rot swap >r >r >r ;
: 2r>  ( -- x y ) r> r> r> swap rot >r ;
: 2r@  ( -- x y ) r> r> r> 2dup >r >r swap rot >r ;
: 2variable  ( | <word> -- ) variable  0 , ;
: 2constant  ( x y | <word> -- ) 
  <builds swap , ,  does>  dup @ swap cell+ @ ;
: 2literal  ( x y -- ) swap literal literal ;
: unless  ( f -- ) postpone 0=  postpone if  ; immediate
: :noname  ( | ... -- xt ) here  '(:) , ] ;
: -;  here  1 cells - dup @  dup @ '(:) <> abort" bad tail call"
  >r  ['] (else) swap !  r> >body ,  postpone ; ; immediate
: callback  ( a -- ) >r ;
variable /search
: search  ( a1 u1 a2 u2 -- a3 u3 f )
  /search !  swap dup >r /search @ - 1+  0  do
    over i + over /search @ swap /search @ compare 0=  if
      drop i +  i  unloop  r> swap -  true  |  loop  drop  r>  false ;
: unused  ( -- u ) imgbase heapsize + here - ;
: concat  ( a1 u1 a2 u2 -- a3 u3 ) \ result in pad
  2swap dup >r pad swap cmove tuck  pad r@ + swap cmove
  r> + pad swap ;

\ words
: words:  ( | ... -- ) r>  context @ @  begin  dup >r  over callback  r>
  count wlen + aligned @ ?dup 0= until  drop ;
: .word  ( a -- )  count wlen type space ;
: words  words:  .word ;

\ sifting
2variable 'sifting
: sifting  ( | <word> -- ) bl word count 'sifting 2!  words:
  dup count wlen 'sifting 2@ search  if  2drop  .word  |
  2drop drop ;

\ dump
: dumpascii  ( a n -- ) [char] | emit                                 
  0 do  count dup 33 128 within 0=  if  drop  [char] .  then
    emit  loop  drop  [char] | emit ; 
: dumpbyte  ( u -- ) dup 16 <  if   [char] 0  emit  then  
  base @ >r  hex  .   r> base ! ;    
: dump  ( a n -- ) dup >r  0  ?do                                
    i 16 mod dup 0= if                                          
      i 0 > if  over 16 dumpascii  16 under+  then              
        cr  2dup + u.  space  then                           
    over + c@ dumpbyte  loop  r> 16 mod ?dup 0=  if  16
    else  16 over - 3 * spaces  then                              
  dumpascii  cr ;

\ interpreter conditionals                        
: processword  ( n1 a n2 -- n3 )                                
  2dup s" [if]" compare 0=  if  2drop 1+ |
  2dup s" [else]" compare 0=  if  2drop dup 1 =  if  1-  then |
  s" [then]" compare 0=  if  1-  then ;                         
: skipwords  ( | ... -- )                                       
  1 begin  bl word dup c@ 0=  if                                     
        drop refill 0= abort" unexpected end of conditional"          
      else  count processword  then                                                      
  ?dup 0=  until ;                                              
: [if]  ( f | ... -- ) 0=  if  skipwords  then ; immediate      
: [else]  ( | ... -- ) skipwords ; immediate                    
: [then] ; immediate                                            
: [defined]  ( | <word> -- f ) bl word find nip ; immediate     
: [undefined]  ( | <word> -- f ) bl word find 0= nip ; immediate

\ save
493 constant OPENX_MODE             
[defined] darwin  [if]  
  208 constant memszoff
  224 constant fileszoff
  h# 10000000 constant imgbase
[else]
  1 cells 4 =  [if]  100  [else]  152  [then] constant fileszoff
  fileszoff cell+ constant memszoff
[then]
h# 10000 constant textsize    
variable savedsize      heapsize savedsize !
512 constant baseoffset   \ size of ELF/Mach-O header
\ compute data/bss segment sizes                                
: memsize  ( -- u ) here imgbase - textsize - ;                        
\ adjust data/bss size
: fixup-filesz  ( a -- ) fileszoff + memsize swap ! ;
: fixup-memsz  ( a -- ) memszoff + savedsize @ swap ! ;
\ copy header and modify, then write to file          
: genhdr  ( fd -- )                                     
  imgbase pad baseoffset cmove                                  
  pad fixup-filesz  pad fixup-memsz  pad  baseoffset  
  rot write-file ?ior ;                     
\ write text + data segments
: gendata  ( fd -- )                                      
  imgbase baseoffset + textsize memsize +                       
  baseoffset - rot write-file ?ior ;                       

\ create file with executable permissions                       
[defined] sys_openat  [if]
: xcreate-file  ( a u -- fd ior ) 
  AT_FDCWD -rot  zstring  w/o OPENX_MODE sys_openat syscall4 dup ior ;
[else]
: xcreate-file  ( a u -- fd ior ) 
  zstring  w/o OPENX_MODE sys_open syscall3 dup ior ;
[then]

\ variant of "boot" for use in unexec'd programs                
variable dpsaved    \ used to restore dp after loading
: xboot  clear  dpsaved @ dp !  forth  startup  bye ;       
defer presave   ' noop is presave      
\ set dp to "xboot" for startup code (restored in xboot)                         
: fixdp  dp @ dpsaved !  s" xboot" dp @ lookup dp ! ;
: saved  ( a u -- )                                           
  presave  2dup delete-file drop  \ delete in case it is running         
  xcreate-file ?ior  fixdp  dup genhdr  dup gendata       
  close-file ?ior ;                                          
: save  ( | <fname> -- ) bl word count saved ;  
: enlarge  ( u -- ) dup savedsize !  ['] heapsize cell+ ! ;
                
\ random numbers - http://excamera.com/sphinx/article-xorshift.html
variable seed   7 seed !
: random    ( -- x )  \ return a 32-bit random number x
  seed @
  dup 13 lshift xor
  dup 17 rshift xor
  dup 5  lshift xor
  dup seed ! ;
: randomize  ( -- )
  s" /dev/urandom" r/o open-file ?ior
  dup seed 4 rot read-file ?ior drop  close-file drop ;

\ structures - taken from forth-standard.org
: begin-structure  \ -- addr 0 ; -- size 
   <builds  here 0 0 ,      \ mark stack, lay dummy 
   does> @ ;            \ -- rec-len 
: end-structure  \ addr n -- 
   swap ! ;          \ set len
: +field  \ n <"name"> -- ; exec: addr -- 'addr 
   <builds over , +  does> @ + ;
: field:    ( n1 "name" -- n2 ; addr1 -- addr2 ) aligned 1 cells +field ;
: cfield:   ( n1 "name" -- n2 ; addr1 -- addr2 ) 1   +field ;
                          
\ where
variable >where
: nextword  ( dp -- dp' ) >cfa >link @ ;
: wafter  ( xt -- dp ) context @  begin  dup >r nextword ?dup
  while  >cfa over =  if  drop  r>  |  r> nextword  repeat  r> 2drop  here ;
: scancode  ( a -- ) dup >cfa dup @ '(:) <>  if  2drop  |  
  dup wafter swap cell+  do  i @ >where @ =  if  unloop  
  .word  |  loop  drop ;
: (where)  ( xt -- ) >where !  words:  scancode ;
: where  ( | <word> -- ) bl word find  if  (where)  |  count undefd ;

\ decompiler
: rfind  ( cfa -- a|0 )                                    
  context @ @  begin  ?dup  while                                            
    dup >r >cfa over =  if  drop  r>  |  r> >cfa >link @
  repeat  drop  false ;                                         
: ?rfind  ( cfa -- a )                                          
  dup rfind ?dup  if  nip  else                                 
    ."  execution token not found: " . cr  true abort  then ;
256 constant maxfwdjmps                                         
maxfwdjmps cells buffer: fwdjmps    variable #fwdjmps
: recbranch  ( a ba -- a )                                      
  2dup <  if fwdjmps #fwdjmps @                                          
    dup maxfwdjmps > abort" too many forward branches"          
    th !  1 #fwdjmps +!  else  drop  then ;                                            
: nofwdjmps?  ( a -- f )                                        
  #fwdjmps @  0  ?do                                            
    fwdjmps i th @ over >=  if  drop false unloop |  loop  
  drop  true ;
: (findend)  ( a1 -- a2 f )                                     
  dup @  1 cells under+
  ['] exit  ->  dup nofwdjmps?  |
  ['] (if)  ->  dup @ recbranch  cell+  false  |
  ['] (else)  ->  dup @ recbranch  cell+  false  |
  ['] (loop)  ->   cell+  false  |   \ assumes branch bwd   
  ['] (+loop)  ->  cell+  false  |  \ same
  ['] (lit)  ->  cell+  false  |                  
  ['] (slit)  ->  count + aligned  false  |  drop  false ;  
: findend  ( a1 -- a2 ) #fwdjmps off  begin  (findend)  until ;
: .name  ( a -- ) count wlen type ;                     
: .name'  ( a -- ) dup .name  c@ 128 and  if  ."  (immediate)"
  then ;
: see-op  ( a1 -- a2 )
  dup u. space  dup @ dup rfind ?dup 0=  if  ." ??? " .  cell+  |
  .name space  1 cells under+
    ['] (if)  ->  dup @ .  cell+  |
    ['] (else)  ->  dup @ .  cell+  |
    ['] (loop)  ->  dup @ .  cell+  |
    ['] (+loop)  ->  dup @ .  cell+ |                     
    ['] (lit)  ->  dup @  .  cell+  |
    ['] (slit)  ->  [char] " emit count 2dup type       
      [char] " emit  space  + aligned  |   drop ;                             
: see-code  ( addr -- )                                         
  dup findend swap  begin  see-op cr  2dup <= until  2drop ;    
: see-(:)  ( cfa -- )                                           
  ?rfind ." : " dup .name' cr  >cfa >body see-code ;            
: see-(variable)  ( cfa -- )                                    
  ?rfind ." variable " dup .name' space >cfa dup [char] @ emit  
  .  ." = "  cell+ @ .  cr ;                         
: see-(constant)  ( cfa -- )                                    
  ?rfind ." constant " dup .name' ."  = " >cfa >body @          
  decimal . hex cr ;                                            
: see-(does)  ( cfa -- )                                        
  ?rfind ." does> " dup .name' space >cfa >body dup @ swap      
  [char] @ emit  . cr see-code ;                                               
: see-(deferred)  ( cfa -- )                                    
  ?rfind ." defer " dup .name' ."  = " >cfa >body @ dup rfind   
  ?dup if .name drop  else  ." ??? " .  then cr ;                                   
: see-primitive  ( cfa -- ) ." primitive " . cr ;               
: (see)  ( addr -- ) base @ swap hex  see-code  base ! ;        
: see  ( | <word> -- )                                          
  ' dup @  '(:)  ->  see-(:)  |
  '(variable)  ->  see-(variable)  |
  '(constant)  ->  see-(constant)  |
  '(does>)  ->  see-(does)  |
  '(defer)  ->  see-(deferred)  |
  dup see-primitive ;

variable >new      variable newdp
: new  >new @ h !  newdp @ dp !  forth ;
here >new !     dp @ newdp !
