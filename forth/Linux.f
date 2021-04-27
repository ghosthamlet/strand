\ System-calls and OS-specific constants (Linux - x86_64/Arm/AArch64/ppc64)

[defined] arm  [if]
197 constant sys_fstat            
48 constant stat.size              80 constant stat.mtime
192 constant sys_mmap        91 constant sys_munmap
144 constant sys_msync       20 constant sys_getpid
162 constant sys_nanosleep
129 constant sys_kill            78 constant sys_gettimeofday
174 constant sys_rt_sigaction
168 constant sys_poll
2 constant sys_fork                11 constant sys_execve
114 constant sys_wait4
63 constant sys_dup2            42 constant sys_pipe
12 constant sys_chdir            54 constant sys_ioctl
[then]
[defined] ppc64  [if]
108 constant sys_fstat            
48 constant stat.size               88 constant stat.mtime
90 constant sys_mmap        91 constant sys_munmap
144 constant sys_msync       20 constant sys_getpid
162 constant sys_nanosleep
37 constant sys_kill            78 constant sys_gettimeofday
173 constant sys_rt_sigaction
167 constant sys_poll
2 constant sys_fork                11 constant sys_execve
114 constant sys_wait4
63 constant sys_dup2            42 constant sys_pipe
12 constant sys_chdir            54 constant sys_ioctl
[then]
[defined] aarch64  [if]
80 constant sys_fstat            
48 constant stat.size               88 constant stat.mtime
222 constant sys_mmap        215 constant sys_munmap
227 constant sys_msync       172 constant sys_getpid
101 constant sys_nanosleep
129 constant sys_kill             169 constant sys_gettimeofday
134 constant sys_rt_sigaction
73 constant sys_ppoll
220 constant sys_clone         221 constant sys_execve
260 constant sys_wait4
24 constant sys_dup3            59 constant sys_pipe2
49 constant sys_chdir            29 constant sys_ioctl
[then]
[defined] x86_64  [if]
5 constant sys_fstat       
48 constant stat.size       88 constant stat.mtime
9 constant sys_mmap     11 constant sys_munmap
26 constant sys_msync   39 constant sys_getpid
35 constant sys_nanosleep  
62 constant sys_kill        96 constant sys_gettimeofday
13 constant sys_rt_sigaction
7 constant sys_poll
57 constant sys_fork       59 constant sys_execve
61 constant sys_wait4     
33 constant sys_dup2     22 constant sys_pipe
80 constant sys_chdir     16 constant sys_ioctl
[then]

32 constant MAP_ANONYMOUS

begin-structure /sigaction
  field: sa.handler     field: sa.flags     field: sa.restorer
  field: sa.mask1       field: sa.mask2  ( mask2 for ARM )
end-structure
/sigaction buffer: sabuf
sabuf sa.mask1 off      sabuf sa.mask2 off
h# 04000000 constant SA_RESTORER
SA_RESTORER sabuf sa.flags !
' sighandler @ sabuf sa.handler !
' sigreturn @ sabuf sa.restorer !
8 constant /ksa
: sigaction  ( sig -- ) sabuf 0 /ksa sys_rt_sigaction syscall4 ior 
  ?ior ;
