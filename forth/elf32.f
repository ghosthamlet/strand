\ ELF executable format

create osversion ," GNU" 0 c,
3 constant elfosabi     \ ELFOSABI_LINUX
16 constant /elfosdesc
: elfosdesc  0 w,  2 w,  6 w,  0 w, ;   \ ABI: 2.6.0

: /elfnote  ( -- u ) 
  osversion c@ 1+ aligned  /elfosdesc aligned +  3 4 * + ;

h# 8000 mbase !       h# 10000 /codesegment !
40 constant elfmachine
h# 5000400 constant elfflags

: header
  cr ." generating ELF32 header ... " cr
  h# 7f c,  h# 45 c,  h# 4c c,  h# 46 c,  decimal        \ ELF magic
  1 c,    \ ELFCLASS32
  1 c,    \ LSB
  1 c,    \ EV_CURRENT
  elfosabi h, 
  7 allot
  2 h,   \ EXEC
  elfmachine h,  
  1 w, \ EV_CURRENT
  512 maddr , \ entry point
  52 ,    \ phoff
  0 ,     \ shoff
  elfflags w,     \ flags
  64 h,    \ ehsize
  32 h,   \ phentsize
  3 h,   \ phnum
  0 h,   \ shentsize
  0 h,   \ shnum
  0 h,   \ shstrndx
  \ PROG headers (code)
  1 w,     \ LOAD
  0 ,     \ offset
  mbase @ dup , ,    \ vaddr, paddr
  h# 10000 dup ,  ,    \ filesz, memsz
  5 w,     \ RE
  h# 8000 ,  \ align
  \ PROG headers (data/bss)
  1 w,     \ LOAD
  /codesegment @ ,  \ offset
  /codesegment @ maddr dup , ,    \ vaddr, paddr
  here datasz !  0 ,    \ filesz (patched)
  heapsize ,  \ memsz
  6 w,     \ RW
  h# 8000 ,  \ align
  \ PROG header (note)
  4 w,     \ NOTE
  here mbuf @ - 7 cells + aligned ,   \ offset
  mbase heapsize + dup , ,    \ vaddr, paddr
  /elfnote dup , ,   \ filesz, memsz
  6 w,     \ RW
  4 ,     \ align
  align
  \ note segment
  osversion c@ aligned w,     \ namesz
  /elfosdesc w,     \ descsz
  1 w,     \ ELF_NOTE_TYPE_OSVERSION
  osversion count 1+ tuck here swap cmove allot align    \ name
  elfosdesc ;  \ desc

create elf
