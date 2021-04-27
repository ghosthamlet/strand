\ System-calls and OS-specific constants (Darwin - x86_64)

h# 20000bd constant sys_fstat       72 constant stat.size
40 constant stat.mtime
h# 20000c5 constant sys_mmap64
h# 2000049 constant sys_munmap
h# 2000041 constant sys_msync
h# 2000014 constant sys_getpid
h# 2000074 constant sys_gettimeofday
h# 20000e6 constant sys_poll
h# 2000002 constant sys_fork
h# 200003b constant sys_execve
h# 2000007 constant sys_wait4
h# 200002a constant sys_pipe
h# 200005a constant sys_dup2
h# 100003e constant sys_clock_sleep
h# 200002e constant sys_sigaction
h# 200000c constant sys_chdir
h# 2000026 constant sys_kill
h# 2000036 constant sys_ioctl

4096 constant MAP_ANONYMOUS

begin-structure /sigaction
  field: sa.handler      field: sa.tramp
  field: sa.mask/flags
end-structure
/sigaction buffer: sabuf  sabuf /sigaction erase
' sigtramp @  sabuf sa.tramp !
: sigaction  ( sig -- ) sabuf 0 sys_sigaction syscall3 ior ?ior ;
