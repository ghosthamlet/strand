\ Linux-specific primitives + stubs

.( Linux )

[defined] x86_64  [if]
105 constant sys_setuid     38 constant sys_setitimer
79 constant sys_getcwd
[else]
[defined] aarch64  [if]
146 constant sys_setuid     103 constant sys_setitimer
17 constant sys_getcwd
[else]
23 constant sys_setuid        104 constant sys_setitimer
[defined] arm  [if]
183 constant sys_getcwd
[else]  \ ppc
182 constant sys_getcwd
[then] [then] [then]

[defined] arm  [defined] aarch64 or  [if]
16 constant stat.mode
[else]
24 constant stat.mode
[then]
