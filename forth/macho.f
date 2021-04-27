\ Mach-O executable format

h# 10000000 mbase !       h# 10000 /codesegment !

h# 19 constant LC_SEGMENT_64
1 constant VM_PROT_READ     2 constant VM_PROT_WRITE
4 constant VM_PROT_EXECUTE
variable lcsize
: (str16)  ( a u -- ) here 16 erase  here swap cmove  16 allot ;
: str16"  ( | ..." -- ) [char] " parse sliteral  postpone (str16) ; immediate
: fixsize  ( a1 a2 -- ) here rot - swap w! ;

: header
  here
  h# feedfacf w,
  h# 01000007 w,   \ CPU_TYPE_X86_64
  h# 80000003 w,  \ CPU_SUBTYPE_X86_64_ALL
  2 w,    \ MH_EXECUTE (filetype)
  4 w,             \ ncmds
  here lcsize ! 0 w,    \ size of all LCs
  1 w,    \ MH_NOUNDEFS (flags)
  0 w,    \ reserved
  \ load commands
  \ pagezero:
  here              \ remember start of LC
  LC_SEGMENT_64 w, \ cmd
  here 0 w,        \ cmdsize (take addr)
  str16" __PAGEZERO"  \ segname
  0 ,            \ vmaddr
  mbase @ ,  \ vmsize
  0 , 0 , 0 w, 0 w,   \ fileoff filesize maxprot initprot
  0 w, 0 w,       \ nsects flags
  fixsize
  \ code segment:
  here
  LC_SEGMENT_64 w,    \ cmd
  here 0 w,        \ cmdsize
  str16" __TEXT"    \ segname
  mbase @ ,     \ vmaddr
  /codesegment @ ,  \ vmsize
  0 ,             \ fileoff
  /codesegment @ ,    \ filesize
  VM_PROT_READ VM_PROT_EXECUTE or dup w, w, \ maxprot initprot
  0 w,             \ nsects
  0 w,             \ flags
  fixsize
  \ data/bss segment:
  here
  LC_SEGMENT_64 w,    \ cmd
  here 0 w,        \ cmdsize
  str16" __DATA"  \ segname
  datasegment ,    \ vmaddr
  heapsize , \ vmsz
  /codesegment @ ,  \ fileoff
  here datasz ! 0 ,    \ filesize
  VM_PROT_READ VM_PROT_WRITE or dup w, w, \ maxprot initprot
  0 w,             \ nsects
  0 w,             \ flags
  fixsize
  \ unixthread segment:
  here
  5 w,     \ LC_UNIXTHREAD (cmd)
  here 0 w,            \ cmdsize
  4 w,   \ X86_THREAD_STATE64 (flavor)
  42 w,   \ X86_THREAD_STATE64_COUNT (count)
  16 cells allot   512 maddr ,  4 cells allot  \ regs (set rip)
  fixsize
  here swap - lcsize @ w! ;  \ fixup sizeofcmds

create macho
