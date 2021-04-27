\ System-call interface

\ little endian:
: h@  ( a -- x ) count swap c@ 8 lshift or ;
: h!  ( x a -- ) >r  dup 255 and r@ c!  8 rshift r> 1+ c! ;
1 cells 4 =  [if]
: w@  ( a -- x ) @ ;     : w!  ( x a -- ) ! ;        : w,  ( x -- ) , ;
[else]
: w@  ( a -- x ) dup h@ swap 2 + h@ 16 lshift or ;
: w!  ( x a -- ) >r  dup 65535 and r@ h!  16 rshift r> 2 + h! ;
: w,  ( x -- ) here w!  4 allot ;
[then]

: exitcode  ( u -- ) sys_exit syscall1 ;

256 buffer: statbuf
: file-size  ( fd -- n ior )
  statbuf sys_fstat syscall2 statbuf stat.size + @ swap ior ;
: file-mtime  ( fd -- n ior )
  statbuf sys_fstat syscall2 statbuf stat.mtime + @ swap ior ;

4 constant MS_SYNC
1 constant MAP_SHARED
1 constant PROT_READ        2 constant PROT_WRITE
4 constant PROT_EXEC
-1 constant r/x
variable mmfd       variable mmacc
: mmaccess  ( acc -- facc mmflags )
  r/x  ->  r/o  PROT_EXEC PROT_WRITE or  |
  w/o  ->  w/o  PROT_WRITE  |  drop  r/w  PROT_WRITE  ;
: mmior  ( x -- a ior ) dup abs 256 >  if  0  else  -1  then ;
[defined] sys_mmap64  [if]
8 cells buffer: mmargs
: map-file  ( a1 u1 acc -- fd a2 u2 ior )  mmaccess mmacc !
  open-file ?dup  if  0 0 2swap  |  mmfd !  mmargs 0 !+  \ addr
  mmfd @ file-size drop dup >r !+   \ len
  mmacc @ PROT_READ or  !+  MAP_SHARED !+  \ prot, flags
  mmfd @ !+  0 !+  off  \ fd, offset
  mmargs sys_mmap64 syscall8
  mmfd @ swap mmior r> swap ;
: map-memory  ( u acc -- a ior )  mmaccess mmacc !  drop
  mmargs 0 !+  swap !+  mmacc @ PROT_READ or !+  \ addr, len, prot
  MAP_SHARED MAP_ANONYMOUS or
    !+  -1 !+  off  \ flags, fd, offset
  mmargs sys_mmap64 syscall8  mmior ;
[else]
: map-file  ( a1 u1 acc -- fd a2 u2 ior )  mmaccess mmacc !
  open-file ?dup  if  r> drop  |  mmfd !
  0  mmfd @ file-size drop dup >r    \ addr, len
  mmacc @ PROT_READ or  MAP_SHARED   \ prot, flags
  mmfd @  0  \ fd, off
  sys_mmap syscall6  mmfd @ swap mmior r> swap ;
: map-memory  ( u acc -- a ior )  mmaccess mmacc !  drop
  0  swap  mmacc @ PROT_READ or   \ addr, len, prot
  MAP_SHARED MAP_ANONYMOUS or  -1  0  \ flags, fd, offset
  sys_mmap syscall6  mmior ;
[then]
: unmap-memory  ( a u -- ior ) sys_munmap syscall2 ior ;
: unmap-file  ( fd a u -- ior ) unmap-memory ?dup  if  nip  |
  close-file drop  0 ;
: map-commit  ( a u -- ) MS_SYNC sys_msync syscall3 ior ;

[defined] sys_gettimeofday  [if]
create tval  0 , 0 ,
: time  ( -- sec ) tval  0  sys_gettimeofday syscall2
  drop tval @ ;
[then]

[defined] sys_clock_sleep  [if]     \ Darwin-specific
: sns? ( u u -- f ) 2>r 0 1 r> r> 0 sys_clock_sleep syscall5 0= ;
: ns? ( u -- f ) 1000000 u/mod sns? ;
: ms?  ( u -- f ) 1000 * ns? ;
: ms  ( u -- ) ms? drop ;
[then]

[defined] sys_nanosleep  [if]
create tspec  0 , 0 ,
: ms?  ( u -- f ) 1000 u/mod tspec !  1000000 * tspec cell+ !   tspec 0
  sys_nanosleep syscall2 0= ;
: ms  ( u -- ) ms? drop ;
[then]

: pid  ( -- u ) sys_getpid syscall0 ;
[defined] sys_kill  [if]
: signal  ( pid sig -- ior ) 
  [defined] darwin  [if]  1  sys_kill syscall3   [else]  sys_kill syscall2  [then]
  ior ;
[then]

[defined] sigaction  [if]
1 constant SIG_IGN
32 cells buffer: sigbuf     sigbuf 32 cells erase
sigbuf signals !
: ignore  ( sig -- ) SIG_IGN sabuf sa.handler !  sigaction ;
: handle  ( sig -- ) ['] sighandler @ sabuf sa.handler !  sigaction ;
: signal?  ( sig -- f ) signals @ swap th dup @  swap off ;
[then]

[defined] sys_poll  [defined] sys_ppoll or  [if]
1 constant POLLIN       4 constant POLLOUT
8 constant POLLERR  16 constant POLLHUP
begin-structure /pollfd
  4 +field pollfd.fd      4 +field pollfd.ev/rev
end-structure
[defined] sys_ppoll  [if]
2variable polltime
: poll  ( fds nfds to -- n ior ) 1000 u/mod polltime !
  1000000 * polltime cell+ !  polltime  0 sys_ppoll syscall4 dup ior ;
[else]
: poll  ( fds nfds to -- n ior ) sys_poll syscall3 dup ior ;
[then]
: poll.fd!  ( u a1 -- ) pollfd.fd w! ;
: poll.ev!  ( u a1 -- ) pollfd.ev/rev h! ;
: poll.rev@  ( a1 -- u ) pollfd.ev/rev 2 + h@ ;
: pollfd  ( fd ev a1 -- a2 ) >r swap r@ pollfd.fd w!
  r@ pollfd.ev/rev w!  r> /pollfd + ;
: pollfd,  ( fd ev -- ) here pollfd h ! ;
[then]

[defined] sys_clone  [if]
: fork  ( -- pid|0 ) 17 ( SIGCHLD ) 0 sys_clone syscall2 dup 
  0< abort" clone(2) failed" ;
[else]
: fork  ( -- pid|0 ) sys_fork syscall0 dup 0< abort" fork(2) failed"
  [defined] forkpid  [if]  forkpid  [then]  ;  \ Darwin
[then]

[defined] sys_wait4  [if]
1 constant WNOHANG
: wifexited  ( status -- f ) h# 7f and 0= ;
: wexitstatus  ( status -- u ) 8 rshift 255 and ;
variable waitstatus
: waitpid  ( pid flags -- status pid ior )                                
  waitstatus swap 0 sys_wait4 syscall4 dup 0<  if  0 0 rot ior |
  waitstatus w@ dup wifexited  if  wexitstatus  then  swap  0 ;
: wait  ( -- status pid ) -1 0 waitpid ?ior ;
: ?wait  ( -- status pid | 0 ) -1 WNOHANG waitpid ?ior
  ?dup 0=  if  drop  0  then ;
[then]

: close  ( fd -- ) close-file drop ;
2variable PATH          variable prevpath       2variable psearched
: getpath  s" PATH" getenv dup >r here swap cmove
  here r@ PATH 2!  r> allot ;
: exists?  ( a u -- f ) r/o open-file  if  drop  false  |  close  true ;
variable trytemp
: trypath  ( a1 u1 -- a1 u1 0 | a2 u2 1 ) trytemp !
  prevpath @ over diff >r  prevpath @ here r@ cmove
  [char] / here r@ + c! 
  psearched 2@  here r@ + 1+ swap dup >r  cmove
  here 2r> + 1+ tuck exists?  if  nip  here swap  true  |
  drop  trytemp @  false ;
\ note: found path is at `here`
: searchpath  ( a1 u1 -- a2 u2 f ) psearched 2!
  PATH @ 0=  if  getpath  then
  PATH 2@  over prevpath !  begin  ( pa pu )
     dup 0>  while
    [char] : scan  trypath ?dup ?exit
    1 /string  over prevpath !
  repeat
  2drop  psearched 2@  false ;

[defined] sys_execve  [if]
4 cells buffer: systemargs  systemargs 3 th off
: execve  ( args env -- |ior ) over @ -rot sys_execve syscall3  ior ;
here  ," /bin/sh" 0 c,  1+ systemargs !
here  ," -c" 0 c,  1+ systemargs 1 th !
: exec  ( a -- ior ) env execve ;
: shell  ( a u -- ) zstring systemargs 2 th !
  systemargs  exec  true abort"  execve(2) failed" ;
: (<fork)  r>  fork ?dup  if  swap @ >r  |  cell+ >r ;
: <fork  ( C: -- a )  postpone (<fork)  here  0 , ; immediate
: fork>  ( -- pid ) ( C: a -- ) postpone bye  here swap ! ; immediate
: system  ( a u -- status )
  <fork  shell  fork>  0 waitpid abort" wait4(2) failed" drop nip nip ;
[then]

[defined] sys_pipe  [if]
8 buffer: pipefds
: pipe  ( -- fdi fdo ior )
  pipefds sys_pipe
[defined] darwin  [if]
  pipecall
[else]
  syscall1
[then]
  ior  pipefds w@  pipefds 4 + w@  rot ;
[then]
[defined] sys_pipe2  [if]
8 buffer: pipefds
: pipe  ( -- fdi fdo ior )
  pipefds  0  sys_pipe2 syscall2 ior
  pipefds w@  pipefds 4 + w@  rot ;
[then]

[defined] sys_dup2  [if]
: dup2  ( fd1 fd2 -- ior ) sys_dup2 syscall2 ior ;
[then]
[defined] sys_dup3  [if]
: dup2  ( fd1 fd2 -- ior ) 0 sys_dup3 syscall3 ior ;
[then]
[defined] dup2  [if]
: (>[])  ( fd1 fd2 -- ) over >r dup2 ?ior r> close ;
: >[]  ( fd -- ) 1 (>[]) ;
: 2>[]  ( fd -- ) 2 (>[]) ;
: <[]  ( fd -- ) 0 (>[]) ;
: (>")  ( fd a u -- ) w/o open-file ?ior  swap (>[]) ;
: (<")  ( a u -- ) r/o open-file ?ior  0 (>[]) ;
: >"  ( | ..." -- ) 1  [char] " parse sliteral  postpone (>") ; immediate
: 2>"  ( | ..." -- ) 2  [char] " parse sliteral  postpone (>") ; immediate
: <"  ( | ..." -- ) [char] " parse sliteral  postpone (<") ; immediate
[then]

[defined] sys_ioctl  [if]
: ioctl  ( fd cmd a -- ior ) sys_ioctl 3 syscall3 ior ;
[then]

: chdir  ( a u -- ) zstring sys_chdir syscall1 ior ;
: cd  ( | <dir> -- ) bl word count chdir ?ior ;
