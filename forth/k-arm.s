## Machine code kernel (ARM, Linux)
## 
## registers:
##
## r0: TOS, r11: W, r12: AP, r13: SP, r14: RP

.equ args, 0x18000
.equ dp, 0x18004
.equ s0, 0x18008
.equ rp0, 0x1800c
.equ signals, 0x18010
.equ errno, 0x18014

    mov r0, sp
    ldr r1, =args
    str r0, [r1]
    sub sp, sp, #1024
    mov r14, sp
    ldr r1, =s0
    str r0, [r1]
    ldr r1, =rp0
    str r14, [r1]
    ldr r1, =dp
    ldr r1, [r1]
    ldrb r2, [r1]
    add r1, r1, r2
    add r1, #4
    bic r1, r1, #3
    add r12, r1, #8     @ fall through
.macro _next
    ldr r11, [r12], #4
    ldr pc, [r11]
.endm
.macro _push x
    str \x, [r13, #-4]!
.endm
.macro _pop x
    ldr \x, [r13], #4
.endm
next:
#= next
    _next
#= (variable)
    _push r0
    add r0, r11, #4
    _next
#= (constant)
    _push r0
    ldr r0, [r11, #4]
    _next
#= (:)
    str r12, [r14], #4
    add r12, r11, #4
    _next
#= (does>)
    str r12, [r14], #4
    ldr r12, [r11, #4]
    _push r0
    add r0, r11, #8
    _next
#= (defer)
    ldr r11, [r11, #4]
    ldr pc, [r11]
# @
    ldr r0, [r0]
    _next
# !
    _pop r1
    str r1, [r0]
    _pop r0
    _next
# on
    mov r1, #-1
    str r1, [r0]
    _pop r0
    _next
# off
    mov r1, #0
    str r1, [r0]
    _pop r0
    _next
# c@ 
    ldrb r0, [r0]
    _next
# c!
    _pop r1
    strb r1, [r0]
    _pop r0
    _next
# count
    ldrb r1, [r0]
    add r0, r0, #1
    _push r0
    mov r0, r1
    _next
# under+
    ldr r1, [r13, #4]
    add r1, r1, r0
    str r1, [r13, #4]
    _pop r0
    _next
# abs
    cmp r0, #0
    rsbmi r0, r0, #0
    _next
# +!
    _pop r1
    ldr r2, [r0]
    add r2, r2, r1
    str r2, [r0]
    _pop r0
    _next
# @+
    ldr r1, [r0], #4
    _push r0
    mov r0, r1
    _next
# !+
    _pop r1
    str r0, [r1], #4
    mov r0, r1
    _next
# +
    _pop r1
    add r0, r0, r1
    _next
# -
    _pop r1
    sub r0, r1, r0
    _next
# *
    _pop r1
    mul r0, r1, r0
    _next
# /mod
    mov r1, r0 
    _pop r0     @ lhs=r0, rhs=r1, div=r2, mod=r3
    eors r5, r0, r1   @ divsgn
    movs r6, r0       @ modsgn
    rsbmi r0, r0, #0
    teq r1, #0
    rsbmi r1, r1, #0
    b udiv32
sdiv32r:
    teq r5, #0
    rsbmi r2, r2, #0
    teq r6, #0
    rsbmi r3, r3, #0
    _push r3
    mov r0, r2
    _next
udiv32:
    mov r2, #0
    mov r3, #0
    mov r4, #32
udivlp1:
    subs r4, r4, #1
    beq sdiv32r
    movs r0, r0, lsl #1
    bpl udivlp1
udiv32_2:
    movs r0, r0, lsl #1
    adc r3, r3, r3
    cmp r3, r1
    subcs r3, r3, r1
    adc r2, r2, r2
    subs r4, r4, #1
    bne udiv32_2
    b sdiv32r
# u*
    _pop r1
    mul r0, r1, r0
    _next
# u/mod
    mov r1, r0
    _pop r0     /* r0/r1 -> r3, r0 (r2: temp) 
http://www.keil.com/support/man/docs/armasm/armasm_dom1359731155623.htm */
    mov r2, r1
    cmp r2, r0, lsr #1
usm1:
    movls r2, r2, lsl #1
    cmp r2, r0, lsr #1
    bls usm1
    mov r3, #0
usm2:
    cmp r0, r2
    subcs r0, r0, r2
    adc r3, r3, r3
    mov r2, r2, lsr #1
    cmp r2, r1
    bhs usm2
    _push r0
    mov r0, r3
    _next
# >
    _pop r1
    cmp r1, r0
    mov r0, #-1
    bgt next
    mov r0, #0
    _next
# <
    _pop r1
    cmp r1, r0
    mov r0, #-1
    blt next
    mov r0, #0
    _next
# >=
    _pop r1
    cmp r1, r0
    mov r0, #-1
    movlt r0, #0
    _next
# <=
    _pop r1
    cmp r1, r0
    mov r0, #-1
    movgt r0, #0
    _next
# u>
    _pop r1
    cmp r1, r0
    mov r0, #-1
    bhi next
    mov r0, #0
    _next
# u<
    _pop r1
    cmp r1, r0
    mov r0, #0
    bhi next
    beq next
    mov r0, #-1
    _next
# =
    _pop r1
    cmp r1, r0
    mov r0, #-1
    movne r0, #0
    _next
# <>
    _pop r1
    cmp r1, r0
    mov r0, #-1
    moveq r0, #0
    _next
# 0=
    cmp r0, #0
    mov r0, #0
    moveq r0, #-1
    _next
# 0<
    cmp r0, #0
    mov r0, #0
    movmi r0, #-1
    _next
# 0>
    cmp r0, #0
    mov r0, #0
    movgt r0, #-1
    _next
# max
    _pop r1
    cmp r1, r0
    movgt r0, r1
    _next
# min
    _pop r1
    cmp r1, r0
    movlt r0, r1
    _next
# and
    _pop r1
    and r0, r0, r1
    _next
# or
    _pop r1
    orr r0, r0, r1
    _next
# xor
    _pop r1
    eor r0, r0, r1
    _next
# invert
    mov r1, #-1
    eor r0, r0, r1
    _next
# negate
    rsb r0, r0, #0
    _next
# lshift
    _pop r1
    lsl r0, r1, r0
    _next
# rshift
    _pop r1
    lsr r0, r1, r0
    _next
# rshifta
    _pop r1
    asr r0, r1, r0
    _next
# 1+
    add r0, r0, #1
    _next
# 1-
    sub r0, r0, #1
    _next
# cell+
    add r0, r0, #4
    _next
# th
    lsl r0, r0, #2
    _pop r1
    add r0, r0, r1
    _next
# swap
    ldr r1, [r13]
    str r0, [r13]
    mov r0, r1
    _next
# drop
    _pop r0
    _next
# 2drop
    add r13, r13, #4
    _pop r0
    _next
# dup
    _push r0
    _next
# ?dup
    cmp r0, #0
    beq lqd1
    _push r0
lqd1:
    _next
# 2dup
    _push r0
    ldr r1, [r13, #4]
    _push r1
    _next
# nip
    add r13, r13, #4
    _next
# over
    _push r0
    ldr r0, [r13, #4]
    _next
# rot
    ldr r1, [r13, #4]
    ldr r2, [r13]
    str r2, [r13, #4]
    str r0, [r13]
    mov r0, r1
    _next
# -rot
    ldr r1, [r13, #4]
    str r0, [r13, #4]
    ldr r0, [r13]
    str r1, [r13]
    _next
# sp@
    _push r0
    mov r0, r13
    _next
# sp!
    _pop r1
    mov r13, r0
    mov r0, r1
    _next
# rp@
    _push r0
    mov r0, r14
    _next
# rp!
    mov r14, r0
    _pop r0
    _next
# >r
    str r0, [r14], #4
    _pop r0
    _next
# r>
    _push r0
    ldr r0, [r14, #-4]!
    _next
# r@
    _push r0
    ldr r0, [r14, #-4]
    _next
# reset
    ldr r1, =rp0
    ldr r14, [r1]
    _next
# 2*
    lsl r0, r0, #1
    _next
# 2/
    asr r0, r0, #1
    _next
# cells
    lsl r0, r0, #2
    _next
# bytes
    asr r0, r0, #2
    _next
# aligned
    add r0, #3
    bic r0, r0, #3
    _next
# (lit)
    _push r0
    ldr r0, [r12]
    add r12, r12, #4
    _next
# (slit)
    _push r0
    add r0, r12, #1
    _push r0
    mov r0, #0
    ldrb r0, [r12]
    add r12, r12, r0
    add r12, r12, #4
    bic r12, r12, #3
    _next
# exit
    sub r14, r14, #4
    ldr r12, [r14]
    _next
# fill
    _pop r1     /* count */
    _pop r2     /* addr */
    cmp r1, #0
    beq fill1
fill2:
    strb r0, [r2], #1
    subs r1, r1, #1
    bne fill2
fill1:
    _pop r0
    _next
# cmove
    _pop r1  /* dest */
    _pop r2  /* src */
    cmp r0, #0
    beq fill1
cmove1:
    ldrb r3, [r2], #1
    strb r3, [r1], #1
    subs r0, r0, #1
    bne cmove1
    b fill1
# cmove>
    _pop r1 /* dest */
    _pop r2 /* src */
    cmp r0, #0
    beq fill1
    add r1, r1, r0
    add r2, r2, r0
cmove2:
    ldrb r3, [r2, #-1]!
    strb r3, [r1, #-1]!
    subs r0, r0, #1
    bne cmove2
    b fill1
# tuck
    _pop r1
    _push r0
    _push r1
    _next
# (if)
    mov r1, r0
    _pop r0
    cmp r1, #0
    beq l10
    add r12, r12, #4
    _next
l10:    # fall through
# (else)
    ldr r12, [r12]
    _next
# (do)
    str r0, [r14]
    _pop r0
    str r0, [r14, #4]
    add r14, r14, #8
    _pop r0
    _next
# (?do)
    _pop r1
    cmp r0, r1
    blt l13
    ldr r12, [r12]
    _pop r0
    _next
l13:
    add r12, r12, #4
    str r0, [r14]
    str r1, [r14, #4]
    add r14, r14, #8
    _pop r0
    _next    
# (loop)
    ldr r1, [r14, #-8]
    add r1, r1, #1
llp:
    ldr r2, [r14, #-4]
    cmp r1, r2
    bge l11
    str r1, [r14, #-8]
    ldr r12, [r12]
    _next
l11:
    sub r14, r14, #8
    add r12, r12, #4
    _next
# (+loop)
    ldr r1, [r14, #-8]
    add r1, r1, r0
    _pop r0
    b llp
# i
    _push r0
    ldr r0, [r14, #-8]
    _next
# j
    _push r0
    ldr r0, [r14, #-16]
    _next
# pick
    mov r1, sp
    lsl r0, r0, #2
    add r1, r1, r0
    ldr r0, [r1]
    _next
# execute
    mov r11, r0
    _pop r0
    ldr pc, [r11]
# halt
    mcr p15, #0, r0, cr7, cr0, #4   /* ARMv7: wfi or wfe */
    _next
# syscall0
    mov r7, r0
    swi #0
    _next
# syscall1
    mov r7, r0
    _pop r0
    swi #0
    _next
# syscall2
    _pop r1
    mov r7, r0
    _pop r0
    swi #0
    _next
# syscall3
    _pop r2
    _pop r1
    mov r7, r0
    _pop r0
    swi #0
    _next
# syscall4
    _pop r3
    _pop r2
    _pop r1
    mov r7, r0
    _pop r0
    swi #0
    _next
# syscall5
    _pop r4
    _pop r3
    _pop r2
    _pop r1
    mov r7, r0
    _pop r0
    swi #0
    _next
# syscall6
    _pop r5
    _pop r4
    _pop r3
    _pop r2
    _pop r1
    mov r7, r0
    _pop r0
    swi #0
    _next
# brk
    swi #1
# lock?
    _pop r2             /* ( a f1 -- f2 ) */
    mov r1, #1
    ldrex r0, [r2]
    teq r0, #0
    mov r0, #0
    bne lock1
    strex r0, r1, [r2]
    teq r0, #0
    moveq r0, #1
    movne r0, #0
lock1:
    _next
# sighandler
    lsl r0, r0, #2
    ldr r1, =signals
    ldr r1, [r1]
    add r0, r1, r0
    mov r2, #1
    str r2, [r0]
    mov pc, lr
/* Linux specific: */
# sigreturn
    mov r7, #119     /* sigreturn */
    swi #0

    .ltorg
