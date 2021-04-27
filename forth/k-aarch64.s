## Machine code kernel (AArch64, Linux)
## 
## registers:
##
## x0: TOS, x11: W, x12: AP, x13: SP, x14: RP

.equ args, 0x410000
.equ dp, 0x410008
.equ s0, 0x410010
.equ rp0, 0x410018
.equ signals, 0x410020
.equ errno, 0x410028

    mov x0, sp
    ldr x1, =args
    str x0, [x1]
    sub sp, sp, #256        /* space for signal handler */
    sub x13, sp, #1024
    mov x14, x13
    ldr x1, =s0
    str x13, [x1]
    ldr x1, =rp0
    str x14, [x1]
    ldr x1, =dp
    ldr x1, [x1]
    ldrb w2, [x1]
    add x1, x1, x2
    add x1, x1, #8
    bic x1, x1, #7
    add x12, x1, #16     /* fall through */
.macro _next
    ldr x11, [x12], #8
    ldr x2, [x11]
    br x2
.endm
.macro _push x
    str \x, [x13, #-8]!
.endm
.macro _pop x
    ldr \x, [x13], #8
.endm
next:
#= next
    _next
#= (variable)
    _push x0
    add x0, x11, #8
    _next
#= (constant)
    _push x0
    ldr x0, [x11, #8]
    _next
#= (:)
    str x12, [x14], #8
    add x12, x11, #8
    _next
#= (does>)
    str x12, [x14], #8
    ldr x12, [x11, #8]
    _push x0
    add x0, x11, #16
    _next
#= (defer)
    ldr x11, [x11, #8]
    ldr x2, [x11]
    br x2
# @
    ldr x0, [x0]
    _next
# !
    _pop x1
    str x1, [x0]
    _pop x0
    _next
# on
    mov x1, #-1
    str x1, [x0]
    _pop x0
    _next
# off
    mov x1, #0
    str x1, [x0]
    _pop x0
    _next
# c@ 
    ldrb w0, [x0]
    _next
# c!
    _pop x1
    strb w1, [x0]
    _pop x0
    _next
# count
    ldrb w1, [x0]
    add x0, x0, #1
    _push x0
    mov x0, x1
    _next
# under+
    ldr x1, [x13, #8]
    add x1, x1, x0
    str x1, [x13, #8]
    _pop x0
    _next
# abs
    cmp x0, #0
    bpl lab1
    neg x0, x0
lab1:
    _next
# +!
    _pop x1
    ldr x2, [x0]
    add x2, x2, x1
    str x2, [x0]
    _pop x0
    _next
# @+
    ldr x1, [x0], #8
    _push x0
    mov x0, x1
    _next
# !+
    _pop x1
    str x0, [x1], #8
    mov x0, x1
    _next
# +
    _pop x1
    add x0, x0, x1
    _next
# -
    _pop x1
    sub x0, x1, x0
    _next
# *
    _pop x1
    mul x0, x1, x0
    _next
# /mod
    mov x1, x0 
    _pop x0
    sdiv x2, x0, x1
    msub x1, x1, x2, x0
    _push x1
    mov x0, x2
    _next
# u*
    _pop x1
    mul x0, x1, x0
    _next
# u/mod
    mov x1, x0
    _pop x0
    udiv x2, x0, x1
    msub x1, x1, x2, x0
    _push x1
    mov x0, x2
    _next
# >
    _pop x1
    cmp x1, x0
    csetm x0, gt
    _next
# <
    _pop x1
    cmp x1, x0
    csetm x0, lt
    _next
# >=
    _pop x1
    cmp x1, x0
    csetm x0, ge
    _next
# <=
    _pop x1
    cmp x1, x0
    csetm x0, le
    _next
# u>
    _pop x1
    cmp x1, x0
    csetm x0, hi
    _next
# u<
    _pop x1
    cmp x1, x0
    mov x0, #0
    bhi next
    beq next
    mov x0, #-1
    _next
# =
    _pop x1
    cmp x1, x0
    csetm x0, eq
    _next
# <>
    _pop x1
    cmp x1, x0
    csetm x0, ne
    _next
# 0=
    cmp x0, #0
    csetm x0, eq
    _next
# 0<
    cmp x0, #0
    csetm x0, lt
    _next
# 0>
    cmp x0, #0
    csetm x0, gt
    _next
# max
    _pop x1 
    cmp x1, x0
    csel x0, x1, x0, gt
    _next
# min
    _pop x1 
    cmp x1, x0
    csel x0, x1, x0, lt
    _next
# and
    _pop x1
    and x0, x0, x1
    _next
# or
    _pop x1
    orr x0, x0, x1
    _next
# xor
    _pop x1
    eor x0, x0, x1
    _next
# invert
    mov x1, #-1
    eor x0, x0, x1
    _next
# negate
    neg x0, x0
    _next
# lshift
    _pop x1
    lsl x0, x1, x0
    _next
# rshift
    _pop x1
    lsr x0, x1, x0
    _next
# rshifta
    _pop x1
    asr x0, x1, x0
    _next
# 1+
    add x0, x0, #1
    _next
# 1-
    sub x0, x0, #1
    _next
# cell+
    add x0, x0, #8
    _next
# th
    lsl x0, x0, #3
    _pop x1
    add x0, x0, x1
    _next
# swap
    ldr x1, [x13]
    str x0, [x13]
    mov x0, x1
    _next
# drop
    _pop x0
    _next
# 2drop
    add x13, x13, #8
    _pop x0
    _next
# dup
    _push x0
    _next
# ?dup
    cmp x0, #0
    beq lqd1
    _push x0
lqd1:
    _next
# 2dup
    _push x0
    ldr x1, [x13, #8]
    _push x1
    _next
# nip
    add x13, x13, #8
    _next
# over
    _push x0
    ldr x0, [x13, #8]
    _next
# rot
    ldr x1, [x13, #8]
    ldr x2, [x13]
    str x2, [x13, #8]
    str x0, [x13]
    mov x0, x1
    _next
# -rot
    ldr x1, [x13, #8]
    str x0, [x13, #8]
    ldr x0, [x13]
    str x1, [x13]
    _next
# sp@
    _push x0
    mov x0, x13
    _next
# sp!
    _pop x1
    mov x13, x0
    mov x0, x1
    _next
# rp@
    _push x0
    mov x0, x14
    _next
# rp!
    mov x14, x0
    _pop x0
    _next
# >r
    str x0, [x14], #8
    _pop x0
    _next
# r>
    _push x0
    ldr x0, [x14, #-8]!
    _next
# r@
    _push x0
    ldr x0, [x14, #-8]
    _next
# reset
    ldr x1, =rp0
    ldr x14, [x1]
    _next
# 2*
    lsl x0, x0, #1
    _next
# 2/
    asr x0, x0, #1
    _next
# cells
    lsl x0, x0, #3
    _next
# bytes
    asr x0, x0, #3
    _next
# aligned
    add x0, x0, #7
    bic x0, x0, #7
    _next
# (lit)
    _push x0
    ldr x0, [x12]
    add x12, x12, #8
    _next
# (slit)
    _push x0
    add x0, x12, #1
    _push x0
    mov x0, #0
    ldrb w0, [x12]
    add x12, x12, x0
    add x12, x12, #8
    bic x12, x12, #7
    _next
# exit
    sub x14, x14, #8
    ldr x12, [x14]
    _next
# fill
    _pop x1     /* count */
    _pop x2     /* addr */
    cmp x1, #0
    beq fill1
fill2:
    strb w0, [x2], #1
    subs x1, x1, #1
    bne fill2
fill1:
    _pop x0
    _next
# cmove
    _pop x1  /* dest */
    _pop x2  /* src */
    cmp x0, #0
    beq fill1
cmove1:
    ldrb w3, [x2], #1
    strb w3, [x1], #1
    subs x0, x0, #1
    bne cmove1
    b fill1
# cmove>
    _pop x1 /* dest */
    _pop x2 /* src */
    cmp x0, #0
    beq fill1
    add x1, x1, x0
    add x2, x2, x0
cmove2:
    ldrb w3, [x2, #-1]!
    strb w3, [x1, #-1]!
    subs x0, x0, #1
    bne cmove2
    b fill1
# tuck
    _pop x1
    _push x0
    _push x1
    _next
# (if)
    mov x1, x0
    _pop x0
    cmp x1, #0
    beq l10
    add x12, x12, #8
    _next
l10:    # fall through
# (else)
    ldr x12, [x12]
    _next
# (do)
    str x0, [x14]
    _pop x0
    str x0, [x14, #8]
    add x14, x14, #16
    _pop x0
    _next
# (?do)
    _pop x1
    cmp x0, x1
    blt l13
    ldr x12, [x12]
    _pop x0
    _next
l13:
    add x12, x12, #8
    str x0, [x14]
    str x1, [x14, #8]
    add x14, x14, #16
    _pop x0
    _next    
# (loop)
    ldr x1, [x14, #-16]
    add x1, x1, #1
llp:
    ldr x2, [x14, #-8]
    cmp x1, x2
    bge l11
    str x1, [x14, #-16]
    ldr x12, [x12]
    _next
l11:
    sub x14, x14, #16
    add x12, x12, #8
    _next
# (+loop)
    ldr x1, [x14, #-16]
    add x1, x1, x0
    _pop x0
    b llp
# i
    _push x0
    ldr x0, [x14, #-16]
    _next
# j
    _push x0
    ldr x0, [x14, #-32]
    _next
# pick
    mov x1, x13
    lsl x0, x0, #3
    add x1, x1, x0
    ldr x0, [x1]
    _next
# execute
    mov x11, x0
    _pop x0
    ldr x2, [x11]
    br x2
# halt
    wfi
    _next
# syscall0
    mov x8, x0
    svc #0
    _next
# syscall1
    mov x8, x0
    _pop x0
    svc #0
    _next
# syscall2
    _pop x1
    mov x8, x0
    _pop x0
    svc #0
    _next
# syscall3
    _pop x2
    _pop x1
    mov x8, x0
    _pop x0
    svc #0
    _next
# syscall4
    _pop x3
    _pop x2
    _pop x1
    mov x8, x0
    _pop x0
    svc #0
    _next
# syscall5
    _pop x4
    _pop x3
    _pop x2
    _pop x1
    mov x8, x0
    _pop x0
    svc #0
    _next
# syscall6
    _pop x5
    _pop x4
    _pop x3
    _pop x2
    _pop x1
    mov x8, x0
    _pop x0
    svc #0
    _next
# brk
    svc #1
# lock?
    _pop x2             /* ( a f1 -- f2 ) */
    mov x1, #1
    ldxr x0, [x2]
    cmp x0, #0
    mov x0, #0
    bne lock1
    stxr w0, x1, [x2]
    mov x3, #1
    cmp x0, #0
    csel x0, x1, x0, eq
lock1:
    _next
# sighandler
    lsl x0, x0, #3
    ldr x1, =signals
    ldr x1, [x1]
    add x0, x1, x0
    mov x2, #1
    str x2, [x0]
    ret
/* Linux specific: */
# sigreturn
    mov x8, #139     /* sigreturn */
    svc #0

    .ltorg


