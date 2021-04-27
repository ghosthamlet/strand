\ System-calls and OS-specific constants (OpenBSD - x86_64)

53 constant sys_fstat               80 constant stat.size
48 constant stat.mtime
197 constant sys_mmap64     73 constant sys_munmap
256 constant sys_msync         20 constant sys_getpid
91 constant sys_nanosleep    122 constant sys_kill
67 constant sys_gettimeofday
46 constant sys_sigaction       252 constant sys_poll
2 constant sys_fork                  59 constant sys_execve
11 constant sys_wait4
90 constant sys_dup2              263 constant sys_pipe
12 constant sys_chdir              54 constant sys_ioctl

4096 constant MAP_ANONYMOUS

begin-structure /sigaction
  field: sa.handler      field: sa.mask/flags
end-structure
/sigaction buffer: sabuf    sabuf sa.mask/flags off
: sigaction  ( sig -- ) sabuf 0 sys_sigaction syscall3 ior ?ior ;
