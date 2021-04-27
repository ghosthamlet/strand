/* Machine code kernel (PowerPC64, Linux)
 
 registers:

 r3: TOS, r1: SP, r14: W, r15: TOC, r16: RP, r17: AP
*/

.equ rTOS, 3
.equ rSP, 1
.equ rW, 14
.equ rTOC, 15
.equ rRP, 16
.equ rAP, 17

.equ mbase, 0x400000
.equ dbase, mbase + 0x10000
.equ args, 0
.equ dp, 8
.equ s0, 16
.equ rp0, 24
.equ signals, 32
.equ errno, 40

    mr rTOC, 0
    lis rTOC, dbase@h
    addis rTOC, rTOC, dbase@l
    std rSP, args(rTOC)
    subi rSP, rSP, 1024
    mr rRP, rSP
    std rSP, s0(rTOC)
    std rRP, rp0(rTOC)
    ld %r5, dp(rTOC)
    lbz %r4, 0(%r5)
    add %r5, %r5, %r4
    addi %r5, %r5, 8
    clrrdi %r5, %r5, 3
    addi rAP, %r5, 16             /* fall through */
.macro _next
    ld rW, 0(rAP)
    addi rAP, rAP, 8
    ld %r4, 0(rW)
    mtlr %r4
    blr
.endm
#= next
    _next

.macro _push x
    stdu \x, -8(rSP)
.endm

.macro _pop x
    ld \x, 0(rSP)
    addi rSP, rSP, 8
.endm

#= (variable)
    _push rTOS
    addi rTOS, rW, 8
    _next
#= (constant)
    _push rTOS
    ld rTOS, 8(rW)
    _next
#= (:)
    std rAP, 0(rRP)
    addi rRP, rRP, 8
    addi rAP, rW, 8
    _next
#= (does>)
    std rAP, 0(rRP)
    addi rRP, rRP, 8
    ld rAP, 8(rW)
    _push rTOS
    addi rTOS, rW, 16
    _next
#= (defer)
    ld rW, 8(rW)
    ld %r4, 0(rW)
    mtlr %r4
    blr
# @
    ld rTOS, 0(rTOS)
    _next
# !
    _pop %r4
    std %r4, 0(rTOS)
    _pop rTOS
    _next
# on
    li %r4, -1
    std %r4, 0(rTOS)
    _pop rTOS
    _next
# off
    li %r4, 0
    std %r4, 0(rTOS)
    _pop rTOS
    _next
# c@ 
    lbz rTOS, 0(rTOS)
    _next
# c!
    _pop %r4
    stb %r4, 0(rTOS)
    _pop rTOS
    _next
# count
    lbz %r4, 0(rTOS)
    addi rTOS, rTOS, 1
    _push rTOS
    mr rTOS, %r4
    _next
# under+
    ld %r4, 8(rSP)
    add %r4, %r4, rTOS
    std %r4, 8(rSP)
    _pop rTOS
    _next
# abs
    cmpdi rTOS, 0
    bge lab1
    neg rTOS, rTOS
lab1:
    _next
# +!
    _pop %r4
    ld %r5, 0(rTOS)
    add %r4, %r4, %r5
    std %r4, 0(rTOS)
    _pop rTOS
    _next
# @+
    ld %r4, 0(rTOS)
    addi rTOS, rTOS, 8
    _push rTOS
    mr rTOS, %r4
    _next
# !+
    _pop %r4
    std rTOS, 0(%r4)
    addi %r4, %r4, 8
    mr rTOS, %r4
    _next
# +
    _pop %r4
    add rTOS, rTOS, %r4
    _next
# -
    _pop %r4
    sub rTOS, %r4, rTOS
    _next
# *    
    _pop %r4
    mulld rTOS, %r4, rTOS
    _next
# /mod
    _pop %r4
    mr %r5, rTOS
    divd rTOS, %r4, %r5
    mulld %r6, rTOS, %r5
    sub %r6, %r4, %r6
    _push %r6
    _next
# u/mod
    _pop %r4
    mr %r5, rTOS
    divdu rTOS, %r4, %r5
    mulld %r6, rTOS, %r5
    sub %r6, %r4, %r6
    _push %r6
    _next
# >
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    bgt lgt1
    li rTOS, 0
lgt1:
    _next
# <
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    blt llt1
    li rTOS, 0
llt1:
    _next
# >=
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    bge lge1
    li rTOS, 0
lge1:
    _next
# <=
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    ble lle1
    li rTOS, 0
lle1:
    _next
# u>
    _pop %r4
    cmpld %r4, rTOS
    li rTOS, -1
    bgt lgt2
    li rTOS, 0
lgt2:
    _next
# u<
    _pop %r4
    cmpld %r4, rTOS
    li rTOS, -1
    blt llt2
    li rTOS, 0
llt2:
    _next
# =
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    beq leq1
    li rTOS, 0
leq1:
    _next
# <>
    _pop %r4
    cmpd %r4, rTOS
    li rTOS, -1
    bne lne1
    li rTOS, 0
lne1:
    _next
# 0=
    cmpdi rTOS, 0
    li rTOS, -1
    beq lz1
    li rTOS, 0
lz1:
    _next
# 0<
    cmpdi rTOS, 0
    li rTOS, -1
    blt ll01
    li rTOS, 0
ll01:
    _next
# 0>
    cmpdi rTOS, 0
    li rTOS, -1
    bgt lg01
    li rTOS, 0
lg01:
    _next
# max
    _pop %r4
    cmpd %r4, rTOS
    ble lma1
    mr rTOS, %r4
lma1:
    _next
# min
    _pop %r4
    cmpd %r4, rTOS
    bge lmi1
    mr rTOS, %r4
lmi1:
    _next
# and
    _pop %r4
    and rTOS, rTOS, %r4
    _next
# or
    _pop %r4
    or rTOS, rTOS, %r4
    _next
# xor
    _pop %r4
    xor rTOS, rTOS, %r4
    _next
# invert
    not rTOS, rTOS
    _next
# negate
    neg rTOS, rTOS
    _next
# lshift
    _pop %r4
    sld rTOS, %r4, rTOS
    _next
# rshift
    _pop %r4
    srd rTOS, %r4, rTOS
    _next
# rshifta
    _pop %r4
    srad rTOS, %r4, rTOS
    _next
# 1+
    addi rTOS, rTOS, 1
    _next
# 1-
    subi rTOS, rTOS, 1
    _next
# cell+
    addi rTOS, rTOS, 8
    _next
# th
    sldi rTOS, rTOS, 3
    _pop %r4
    add rTOS, rTOS, %r4
    _next
# swap
    ld %r4, 0(rSP)
    std rTOS, 0(rSP)
    mr rTOS, %r4
    _next
# drop
    _pop rTOS
    _next
# 2drop
    addi rSP, rSP, 8
    _pop rTOS
    _next
# dup
    _push rTOS
    _next
# ?dup
    cmpdi rTOS, 0
    beq lqd1
    _push rTOS
lqd1:
    _next
# 2dup
    _push rTOS
    ld %r4, 8(rSP)
    _push %r4
    _next  
# nip
    addi rSP, rSP, 8
    _next
# over
    _push rTOS
    ld rTOS, 8(rSP)
    _next
# rot
    ld %r4, 8(rSP)
    ld %r5, 0(rSP)
    std %r5, 8(rSP)
    std rTOS, 0(rSP)
    mr rTOS, %r4
    _next
# -rot
    ld %r4, 8(rSP)
    std rTOS, 8(rSP)
    ld rTOS, 0(rSP)
    std %r4, 0(rSP)
    _next
# sp@
    _push rTOS
    mr rTOS, rSP
    _next
# sp!
    _pop %r4
    mr rSP, rTOS
    mr rTOS, %r4
    _next
# rp@
    _push rTOS
    mr rTOS, rRP
    _next
# rp!
    mr rRP, rTOS
    _pop rTOS
    _next
# >r
    std rTOS, 0(rRP)
    addi rRP, rRP, 8
    _pop rTOS
    _next
# r>
    _push rTOS
    ldu rTOS, -8(rRP)
    _next
# r@
    _push rTOS
    ld rTOS, -8(rRP)
    _next
# reset
    ld rRP, rp0(rTOC)
    _next
# 2*
    sldi rTOS, rTOS, 1
    _next
# 2/
    sradi rTOS, rTOS, 1
    _next
# cells
    sldi rTOS, rTOS, 3
    _next
# bytes
    sradi rTOS, rTOS, 3
    _next
# aligned
    addi rTOS, rTOS, 7
    clrrdi rTOS, rTOS, 3
    _next
# (lit)
    _push rTOS
    ld rTOS, 0(rAP)
    addi rAP, rAP, 8
    _next
# (slit)
    _push rTOS
    addi rTOS, rAP, 1
    _push rTOS
    lbz rTOS, 0(rAP)
    add rAP, rAP, rTOS
    addi rAP, rAP, 8
    clrrdi rAP, rAP, 3
    _next
# exit
    ldu rAP, -8(rRP)
    _next
# fill
    _pop %r4     /* count */
    _pop %r5     /* addr */
    cmpdi %r4, 0
    beq fill1
    mtctr %r4
    subi %r5, %r5, 1
fill2:
    stbu rTOS, 1(%r5)
    bdnz fill2
fill1:
    _pop rTOS
    _next
# cmove
    _pop %r4  /* dest */
    _pop %r5  /* src */
    cmpdi rTOS, 0
    beq fill1
    mtctr rTOS
    subi %r5, %r5, 1
    subi %r4, %r4, 1
cmove1:
    lbzu %r6, 1(%r5)
    stbu %r6, 1(%r4)
    bdnz cmove1
    b fill1
# cmove>
    _pop %r4 /* dest */
    _pop %r5 /* src */
    cmpdi rTOS, 0
    beq fill1
    mtctr rTOS
    add %r4, %r4, rTOS
    add %r5, %r5, rTOS
cmove2:
    lbzu %r6, -1(%r5)
    stbu %r6, -1(%r4)
    bdnz cmove2
    b fill1
# tuck
    _pop %r4
    _push rTOS
    _push %r4
    _next
# (if)
    mr %r4, rTOS
    _pop rTOS
    cmpdi %r4, 0
    beq l10
    addi rAP, rAP, 8
    _next
l10:    # fall through
# (else)
    ld rAP, 0(rAP)
    _next
# (do)
    std rTOS, 0(rRP)
    _pop rTOS
    std rTOS, 8(rRP)
    addi rRP, rRP, 16
    _pop rTOS
    _next
# (?do)
    _pop %r4
    cmpd rTOS, %r4
    blt l13
    ld rAP, 0(rAP)
    _pop rTOS
    _next
l13:
    addi rAP, rAP, 8
    std rTOS, 0(rRP)
    std %r4, 8(rRP)
    addi rRP, rRP, 16
    _pop rTOS
    _next    
# (loop)
    ld %r4, -16(rRP)
    addi %r4, %r4, 1
llp:
    ld %r5, -8(rRP)
    cmpd %r4, %r5
    bge l11
    std %r4, -16(rRP)
    ld rAP, 0(rAP)
    _next
l11:
    subi rRP, rRP, 16
    addi rAP, rAP, 8
    _next
# (+loop)
    ld %r4, -16(rRP)
    add %r4, %r4, rTOS
    _pop rTOS
    b llp
# i
    _push rTOS
    ld rTOS, -16(rRP)
    _next
# j
    _push rTOS
    ld rTOS, -32(rRP)
    _next
# pick
    mr %r4, rSP
    sldi rTOS, rTOS, 3
    add %r4, %r4, rTOS
    ld rTOS, 0(%r4)
    _next
# execute
    mr rW, rTOS
    _pop rTOS
    ld %r4, 0(rW)
    mtlr %r4
    blr
# syscall0
    mr %r0, rTOS
lsys:
    sc
    bns lsys1
    std %r3, errno(rTOC)
    li rTOS, -1
lsys1:
    _next
# syscall1
    mr %r0, rTOS
    _pop %r3
    b lsys
# syscall2
    mr %r0, rTOS
    _pop %r4
    _pop %r3
    b lsys
# syscall3
    mr %r0, rTOS
    _pop %r5
    _pop %r4
    _pop %r3
    b lsys
# syscall4
    mr %r0, rTOS
    _pop %r6
    _pop %r5
    _pop %r4
    _pop %r3
    b lsys
# syscall5
    mr %r0, rTOS
    _pop %r7
    _pop %r6
    _pop %r5
    _pop %r4
    _pop %r3
    b lsys
# syscall6
    mr %r0, rTOS
    _pop %r8
    _pop %r7
    _pop %r6
    _pop %r5
    _pop %r4
    _pop %r3
    b lsys
# brk
    trap
# lock?
    _pop %r4             /* ( a f1 -- f2 ) */
    li %r5, 1
    ldarx rTOS, 0, %r4
    cmpdi rTOS, 0
    li rTOS, 0
    bne ltl1
    stdcx. %r5, 0, %r4
    li rTOS, 0
    bne ltl1
    isync
    addi rTOS, rTOS, 1
ltl1:
    _next
# sighandler
    ld %r4, signals(rTOC)
    sldi %r3, %r3, 3
    li %r5, 1
    add %r4, %r4, %r3
    std %r5, 0(%r4)
    blr
# sigreturn
    li %r0, 119     /* sigreturn */
    sc
