\ ELF executable format (64 bit)

[defined] target-OpenBSD  [if]
create osversion ," OpenBSD" 0 c,
12 constant elfosabi \ ELFOSABI_OPENBSD
4 constant /elfosdesc
: elfosdesc  0 w, ;
[then]
[defined] target-Linux  [if]
create osversion ," GNU" 0 c,
[defined] target-aarch64  [if]  0  [else]  3  [then]
  constant elfosabi     \ ELFOSABI_LINUX
16 constant /elfosdesc
: elfosdesc  0 w,  2 w,  6 w,  0 w, ;   \ ABI: 2.6.0
[then]

: /elfnote  ( -- u ) 
  osversion c@ 1+ aligned  /elfosdesc aligned +  3 4 * + ;

h# 400000 mbase !       h# 10000 /codesegment !
[defined] target-ppc64  [if]
21 constant elfmachine
2 constant elfflags     \ abiv2 (LE)
[else] [defined] target-aarch64  [if]
h# b7 constant elfmachine
0 constant elfflags
[else]
62 constant elfmachine      \ x86_64
0 constant elfflags
[then] [then]

: header
  cr ." generating ELF64 header ... " cr
  h# 7f c,  h# 45 c,  h# 4c c,  h# 46 c,  decimal        \ ELF magic
  2 c,    \ ELFCLASS64
  1 c,    \ LSB
  1 c,    \ EV_CURRENT
  elfosabi h, 
  7 allot
  2 h,   \ EXEC
  elfmachine h,  
  1 w, \ EV_CURRENT
  512 maddr , \ entry point
  64 ,    \ phoff
  0 ,     \ shoff
  elfflags w,     \ flags
  64 h,    \ ehsize
  56 h,   \ phentsize
  3 h,   \ phnum
  0 h,   \ shentsize
  0 h,   \ shnum
  0 h,   \ shstrndx
  \ PROG headers (code)
  1 w,     \ LOAD
  5 w,     \ RE
  0 ,     \ offset
  mbase @ dup , ,    \ vaddr, paddr
  h# 10000 dup ,  ,    \ filesz, memsz
  h# 10000 ,  \ align
  \ PROG headers (data/bss)
  1 w,     \ LOAD
  6 w,     \ RW
  /codesegment @ ,  \ offset
  /codesegment @ maddr dup , ,    \ vaddr, paddr
  here datasz !  0 ,    \ filesz (patched)
  heapsize ,  \ memsz
  h# 10000 ,  \ align
  \ PROG header (note)
  4 w,     \ NOTE
  6 w,     \ RW
  here mbuf @ - 6 cells + aligned ,   \ offset
  mbase heapsize + dup , ,    \ vaddr, paddr
  /elfnote dup , ,   \ filesz, memsz
  4 ,     \ align
  align
  \ note segment
  osversion c@ aligned w,     \ namesz
  /elfosdesc w,     \ descsz
  1 w,     \ ELF_NOTE_TYPE_OSVERSION
  osversion count 1+ tuck here swap cmove allot align    \ name
  elfosdesc ;  \ desc

create elf
