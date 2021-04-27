;; Machine code kernel (x86_64, Linux/OpenBSD/Darwin)
;;
;; registers:
;;
;; rax: TOS, rsp: SP, rbp: RP, rsi: AP, rdi: W

    bits 64

%ifdef Darwin
%define mbase 0x10000000
%else
%define mbase 0x400000
%endif

    org mbase + 512

dbase equ mbase + 0x10000
args equ dbase
dp equ dbase + 8
s0 equ dbase + 16
r0 equ dbase + 24
signals equ dbase + 32
errno equ dbase + 40

    mov rax, rsp
    mov [args], rax
    sub rsp, 1024
    mov rbp, rsp
    mov [s0], rsp
    mov [r0], rbp
    mov rax, [dp]
    xor rcx, rcx
    mov cl, [rax]
    add rax, rcx
    add rax, 8
    and rax, ~7
    lea rsi, [rax + 16]     ; fall through ...
%macro _next 0
    mov rdi, [rsi]
    add rsi, 8
    mov rbx, [rdi]
    jmp rbx
%endmacro
;= next
next:
    _next
;= (variable)
    push rax
    lea rax, [rdi + 8]
    _next
;= (constant)
    push rax
    mov rax, [rdi + 8]
    _next
;= (:)
    mov [rbp], rsi
    add rbp, 8
    lea rsi, [rdi + 8]
    _next
;= (does>)
    mov [rbp], rsi
    add rbp, 8
    mov rsi, [rdi + 8]
    push rax
    lea rax, [rdi + 16]
    _next
;= (defer)
    mov rdi, [rdi + 8]
    mov rbx, [rdi]
    jmp rbx
; @
    mov rax, [rax]
    _next
; !
    pop rbx
    mov [rax], rbx
    pop rax
    _next
; on
    mov rbx, -1
    mov [rax], rbx
    pop rax
    _next
; off
    xor rbx, rbx
    mov [rax], rbx
    pop rax
    _next
; c@
    mov al, [rax]
    and rax, 255
    _next
; c!
    pop rbx
    mov [rax], bl
    pop rax
    _next
; count
    mov bl, [rax]
    and rbx, 255
    inc rax
    push rax
    mov rax, rbx
    _next
; under+
    add [rsp + 8], rax
    pop rax
    _next
; abs
    cmp rax, 0
    jge lab1
    neg rax
lab1:
    _next
; +!
    pop rbx
    add [rax], rbx
    pop rax
    _next
; @+
    mov rbx, [rax]
    add rax, 8
    push rax
    mov rax, rbx
    _next
; !+
    pop rbx
    mov [rbx], rax
    add rbx, 8
    mov rax, rbx
    _next
; +
    pop rbx
    add rax,rbx
    _next
; -
    pop rbx
    xchg rax, rbx
    sub rax, rbx
    _next
; *
    pop rbx
    imul rbx
    _next
; /mod
    pop rbx
    xchg rax, rbx
    cqo
    idiv rbx
    push rdx
    _next
; u*
    pop rbx
    mul rbx
    _next
; u/mod
    pop rbx
    xchg rax, rbx
    xor rdx, rdx
    div rbx
    push rdx
    _next
; */
    mov rcx, rax
    pop rbx
    pop rax
    imul rbx
    idiv rcx
    _next
; >
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jg lg1
    xor rax, rax
lg1:
    _next
; <
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jl le1
    xor rax, rax
le1:
    _next
; >=
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jge lge1
    xor rax, rax
lge1:
    _next
; <=
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jle lle1
    xor rax, rax
lle1:
    _next
; u>
    pop rbx
    cmp rbx, rax
    mov rax, -1
    ja la1
    xor rax, rax
la1:
    _next
; u<
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jb lb1
    xor rax, rax
lb1:
    _next
; =
    pop rbx
    cmp rbx, rax
    mov rax, -1
    je leq1
    xor rax, rax
leq1:
    _next
; <>
    pop rbx
    cmp rbx, rax
    mov rax, -1
    jne lne1
    xor rax, rax
lne1:
    _next
; 0=
    cmp rax, 0
    mov rax, -1
    je lz1
    xor rax, rax
lz1:
    _next
; 0<
    cmp rax, 0
    mov rax, -1
    jl ll01
    xor rax, rax
ll01:
    _next
; 0>
    cmp rax, 0
    mov rax, -1
    jg lg01
    xor rax, rax
lg01:
    _next
; max
    pop rbx
    cmp rbx, rax
    jle lma1
    mov rax, rbx
lma1:
    _next
; min
    pop rbx
    cmp rbx, rax
    jge lmi1
    mov rax, rbx
lmi1:
    _next
; and
    pop rbx
    and rax, rbx
    _next
; or
    pop rbx
    or rax, rbx
    _next
; xor
    pop rbx
    xor rax, rbx
    _next
; invert
    not rax
    _next
; negate
    neg rax
    _next
; lshift
    mov cl, al
    pop rax
    shl rax, cl
    _next
; rshift
    mov rcx, rax
    pop rax
    shr rax, cl
    _next
; rshifta
    mov rcx, rax
    pop rax
    sar rax, cl
    _next
; 1+
    inc rax
    _next
; 1-
    dec rax
    _next
; cell+
    add rax, 8
    _next
; th
    shl rax, 3
    pop rbx
    add rax, rbx
    _next
; swap
    xchg [rsp], rax
    _next
; drop
    pop rax
    _next
; 2drop
    add rsp, 8
    pop rax
    _next
; dup
    push rax
    _next
; ?dup
    cmp rax, 0
    je lqd1
    push rax
lqd1:
    _next
; 2dup
    push rax
    mov rbx, [rsp + 8]
    push rbx
    _next
; nip
    add rsp, 8
    _next
; over
    push rax
    mov rax, [rsp + 8]
    _next
; rot
    mov rbx, [rsp + 8]
    mov rcx, [rsp]
    mov [rsp + 8], rcx
    mov [rsp], rax
    mov rax, rbx
    _next
; -rot
    mov rbx, [rsp + 8]
    mov [rsp + 8], rax
    mov rax, [rsp]
    mov [rsp], rbx
    _next
; sp@
    push rax
    mov rax, rsp
    _next
; sp!
    pop rbx
    mov rsp, rax
    mov rax, rbx
    _next
; rp@
    push rax
    mov rax, rbp
    _next
; rp!
    mov rbp, rax
    pop rax
    _next
; >r
    mov [rbp], rax
    add rbp, 8
    pop rax
    _next
; r>
    push rax
    sub rbp, 8
    mov rax, [rbp]
    _next
; r@
    push rax
    mov rax, [rbp - 8]
    _next
; reset
    mov rbp, [r0]
    _next
; 2*
    shl rax, 1
    _next
; 2/
    sar rax, 1
    _next
; cells
    shl rax, 3
    _next
; bytes
    sar rax, 3
    _next
; aligned
    add rax, 7
    and rax, ~7
    _next
; (lit)
    push rax
    mov rax, [rsi]
    add rsi, 8
    _next
; (slit)
    push rax
    lea rax, [rsi + 1]
    push rax
    xor rax, rax
    mov al, [rsi]
    add rsi, rax
    add rsi, 8
    and rsi, ~7
    _next
; exit
    sub rbp, 8
    mov rsi, [rbp]
    _next
; fill
    pop rcx
    pop rbx
    push rdi
    mov rdi, rbx
    cld
    rep stosb
    pop rdi
    pop rax
    _next
; cmove
    pop rbx
    pop rdx
    push rsi
    push rdi
    mov rsi, rdx
    mov rdi, rbx
    mov rcx, rax
    cld
    rep movsb
    pop rdi
    pop rsi
    pop rax
    _next
; cmove>
    pop rbx
    pop rdx
    mov rcx, rax
    dec rax
    push rsi
    push rdi
    mov rsi, rdx
    mov rdi, rbx
    add rsi, rax
    add rdi, rax
    std
    rep movsb
    pop rdi
    pop rsi
    pop rax
    _next
; tuck
    pop rbx
    push rax
    push rbx
    _next
; (if)
    mov rcx, rax
    pop rax
    cmp rcx, 0
    jz l10
    add rsi, 8
    _next
l10:    ; fall through
; (else)
    mov rsi, [rsi]
    _next
; (do)
    mov [rbp], rax
    pop rax
    mov [rbp + 8], rax
    add rbp, 16
    pop rax
    _next
; (?do)
    pop rcx
    cmp rax, rcx
    jl l13
    mov rsi, [rsi]
    pop rax
    _next
l13:
    add rsi, 8
    mov [rbp], rax
    mov [rbp + 8], rcx
    add rbp, 16
    pop rax
    _next
; (loop)
    mov rcx, [rbp - 16]
    inc rcx
llp:
    cmp rcx, [rbp - 8]
    jge l11
    mov [rbp - 16], rcx
    mov rsi, [rsi]
    _next
l11:
    sub rbp, 16
    add rsi, 8
    _next
; (+loop)
    mov rcx, [rbp - 16]
    add rcx, rax
    pop rax
    jmp llp
; i
    push rax
    mov rax, [rbp - 16]
    _next
; j
    push rax
    mov rax, [rbp - 32]
    _next
; pick
    mov rbx, rsp
    shl rax, 3
    add rbx, rax
    mov rax, [rbx]
    _next
; execute
    mov rdi, rax
    pop rax
    mov rbx, [rdi]
    jmp rbx
; halt
    hlt
    _next
; syscall0
    syscall
lsys:
%ifndef Linux
    jnc ls1
err:
    mov [errno], rax
    mov rax, -1
ls1:
%endif
    _next
; syscall1
    pop rdi
    syscall
    jmp lsys
; syscall2
lsys2:
    pop rcx
    pop rdi
    push rsi
    mov rsi, rcx
    syscall
    pop rsi
    jmp lsys
; syscall3
    pop rdx
    jmp lsys2
; syscall4
    pop r10
    pop rdx
    jmp lsys2
; syscall5
    pop r8
    pop r10
    pop rdx
    jmp lsys2
; syscall6
    pop r9
    pop r8
    pop r10
    pop rdx
    jmp lsys2
; syscall8
    pop rbx
    push rsi
    mov rdi, [rbx]
    mov rsi, [rbx + 8]
    mov rdx, [rbx + 16]
    mov r10, [rbx + 24]
    mov r8, [rbx + 32]
    mov r9, [rbx + 40]
    push qword [rbx + 56]
    push qword [rbx + 48]
    syscall
    pop rbx
    pop rbx
    pop rsi
    jmp lsys
; brk
    int 3
    _next
; cas
    pop rbx      ; ( new old a -- f )
    xchg rbx, rax
    pop rdx
    lock cmpxchg [rbx], rdx
    jz cas1
    xor rax, rax
    _next
cas1:
    mov rax, -1
    _next
; sighandler
    mov rbx, [signals]
    shl rdi, 3
    mov rax, 1
    mov [rbx + rdi], rax
    ret
%ifdef Linux
; sigreturn
    mov rax, 15     ; sigreturn
    syscall
%endif
%ifdef Darwin
; forkpid
    or edx, edx
    jz lfp1
    xor rax, rax
lfp1:
    _next
; pipecall
    pop rdi
    syscall
    jc err
    mov [rdi], eax
    mov [rdi+4], edx
    xor rax, rax
    jmp next
; sigtramp
    mov rax, rdi
    mov rdi, rdx
    call rax
    mov rsi, 0x1e 	; flavor
    mov rdi, r8		; ucontext
    mov rax, 0x20000b8  ; sigreturn
    syscall
%endif
