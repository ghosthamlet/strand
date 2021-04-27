% Strand lexical analyzer

-exports([lex_file/3, lex/4]).

lex_file(FNAME, O, E) :-
    open_file(FNAME, r, FD),
    io:read_char_stream(FD, I),
    lex(I, 1, O, E).

lex([], _, O, E) :- O := [], E := [].
lex([C|R], L, O, E) :- C >= 0'a, C =< 0'z | ident(C, R, L, O, E).
lex([C|R], L, O, E) :- C >= 0'0, C =< 0'9 | num(C, R, L, O, E).
lex([C|R], L, O, E) :- C >= 0'A, C =< 0'Z | var(C, R, L, O, E).
lex([0'_|R], L, O, E) :- var(0'_, R, L, O, E).
lex([0',|R], L, O, E) :- punct(0',, R, L, O, E).
lex([0'.|R], L, O, E) :- punct(0'., R, L, O, E).
lex([0'[|R], L, O, E) :- punct(0'[, R, L, O, E).
lex([0']|R], L, O, E) :- punct(0'], R, L, O, E).
lex([0'||R], L, O, E) :- punct(0'|, R, L, O, E).
lex([0'(|R], L, O, E) :- punct(0'(, R, L, O, E).
lex([0')|R], L, O, E) :- punct(0'), R, L, O, E).
lex([0'{|R], L, O, E) :- punct(0'{, R, L, O, E).
lex([0'}|R], L, O, E) :- punct(0'}, R, L, O, E).
lex([0'#|R], L, O, E) :- hex(R, L, O, E).
lex([10|R], L, O, E) :- L2 is L + 1, lex(R, L2, O, E).
lex([0''|R], L, O, E) :- str(R, L, O, E).
lex([0'"|R], L, O, E) :- charlist(R, L, O, E).
lex([0'%|R], L, O, E) :- skip(R, L, O, E).
lex([32|R], L, O, E) :- lex(R, L, O, E).
lex([9|R], L, O, E) :- lex(R, L, O, E).
lex([13|R], L, O, E) :- lex(R, L, O, E).
lex(TL, L, O, E) :- otherwise | op(TL, L, O, E).

skip([], _, O, E) :- O := [], E := [].
skip([10|R], L, O, E) :- L2 is L + 1, lex(R, L2, O, E).
skip([C|R], L, O, E) :- C =\= 10 | skip(R, L, O, E).

ident(C, R, L, O, E) :- 
    scan_ident(R, R2, LST),
    list_to_string([C|LST], ID),
    O := [id(L, ID)|O2],
    lex(R2, L, O2, E).

scan_ident([0'_|R], R2, LST) :- 
    LST := [0'_|LST2], scan_ident(R, R2, LST2).
scan_ident([C|R], R2, LST) :- 
    C >= 0'a, C =< 0'z | LST := [C|LST2], scan_ident(R, R2, LST2).
scan_ident([C|R], R2, LST) :- 
    C >= 0'0, C =< 0'9 | LST := [C|LST2], scan_ident(R, R2, LST2).
scan_ident([C|R], R2, LST) :- 
    C >= 0'A, C =< 0'Z | LST := [C|LST2], scan_ident(R, R2, LST2).
scan_ident(R, R2, LST) :- 
    otherwise | R2 := R, LST := [].

num(0'0, [0'', C|R], L, O, E) :-
    esc([C|R], R2, CO),
    O := [num(L, CO)|O2],
    lex(R2, L, O2, E).
num(C, R, L, O, E) :- 
    otherwise |
    scan_num(R, R2, LST),
    num2(R2, L, [C|LST], O, E).

num2([0''|R], L, LST, O, E) :-
    list_to_integer(LST, BASE),
    base_crange(BASE, CR1, CR2),
    scan_bnum(R, CR1, CR2, R2, LST2),
    list_to_integer(LST2, BASE, NUM),
    O := [num(L, NUM)|O2],
    lex(R2, L, O2, E).
num2(R, L, LST, O, E) :-
    otherwise |    
    list_to_integer(LST, NUM),
    O := [num(L, NUM)|O2],
    lex(R, L, O2, E).

scan_num([C|R], R2, LST) :- 
    C >= 0'0, C =< 0'9 | LST := [C|LST2], scan_num(R, R2, LST2).
scan_num(R, R2, LST) :- 
    otherwise | R2 := R, LST := [].

scan_bnum([C|R], CR1, CR2, R2, LST) :- 
    tolower(C, CLO),
    scan_bnum1([CLO|R], CR1, CR2, R2, LST).

scan_bnum1([C|R], {CL, CH}, CR2, R2, LST) :- 
    C >= CL, C =< CH | 
    LST := [C|LST2], 
    scan_bnum(R, {CL, CH}, CR2, R2, LST2).
scan_bnum1([C|R], CR1, {CL, CH}, R2, LST) :- 
    C >= CL, C =< CH | 
    LST := [C|LST2], 
    scan_bnum(R, CR1, {CL, CH}, R2, LST2).
scan_bnum1(R, _, _, R2, LST) :- 
    otherwise | R2 := R, LST := [].

base_crange(BASE, CR1, CR2) :-
    BASE =< 10 | 
    CH1 is 0'0 + BASE,
    CR1 := {0'0, CH1},
    CR2 := xxx.
base_crange(BASE, CR1, CR2) :-
    BASE > 10 | 
    CH2 is 0'a + BASE - 11,
    CR1 := {0'0, 0'9},
    CR2 := {0'a, CH2}.

tolower(C, CL) :- C >= 0'A, C =< 0'Z | CL is C + 32.
tolower(C, CL) :- otherwise | CL := C.

var(C, R, L, O, E) :-
    scan_ident(R, R2, LST),
    list_to_string([C|LST], VAR),
    O := [var(L, VAR)|O2],
    lex(R2, L, O2, E).

punct(C, R, L, O, E) :-
    O := [punct(L, C)|O2], lex(R, L, O2, E).

op(TL, L, O, E) :-
    scan_op(TL, R2, LST), op1(LST, L, R2, O, E).

op1([], L, [C|_], O, E) :- 
    E := [{L, 'invalid character "~c"\n', [C], 1}], O := [].
op1(LST, L, R, O, E) :-
    otherwise |
    list_to_string(LST, OP),
    O := [op(L, OP)|O2],
    lex(R, L, O2, E).

scan_op([0':|R], R2, LST) :- 
    LST := [0':|LST2], scan_op(R, R2, LST2).
scan_op([0'-|R], R2, LST) :- 
    LST := [0'-|LST2], scan_op(R, R2, LST2).
scan_op([0'/|R], R2, LST) :- 
    LST := [0'/|LST2], scan_op(R, R2, LST2).
scan_op([0'\\|R], R2, LST) :- 
    LST := [0'\\|LST2], scan_op(R, R2, LST2).
scan_op([0'&|R], R2, LST) :- 
    LST := [0'&|LST2], scan_op(R, R2, LST2).
scan_op([C|R], R2, LST) :- 
    C >= 0'*, C =< 0'+ | LST := [C|LST2], scan_op(R, R2, LST2).
scan_op([C|R], R2, LST) :- 
    C >= 0'<, C =< 0'@ | LST := [C|LST2], scan_op(R, R2, LST2).
scan_op(R, R2, LST) :- 
    otherwise | R2 := R, LST := [].

str(R, L, O, E) :-
    scan_str(R, 0'', R2, LST, E, E2),
    list_to_string(LST, STR),
    O := [str(L, STR)|O2],
    lex(R2, L, O2, E2).

charlist(R, L, O, E) :-
    scan_str(R, 0'", R2, LST, E, E2),
    O := [lst(L, LST)|O2],
    lex(R2, L, O2, E2).

scan_str([], _, R, _, E, E2) :-
    R := [], 
    E := [{0, 'premature end of string~n', [], 1}|E2].
scan_str([0'\\, C|R], DELIM, R2, LST, E, E2) :-
    esc(C, CO),
    LST := [CO|LST2],
    scan_str(R, DELIM, R2, LST2, E, E2).
scan_str([DELIM|R], DELIM, R2, LST, E, E2) :-
    R2 := R, LST := [], E2 := E.
scan_str([C|R], DELIM, R2, LST, E, E2) :-
    C =\= DELIM, C =\= 0'\\ | 
    LST := [C|LST2], 
    scan_str(R, DELIM, R2, LST2, E, E2).

esc([0'\\, EC|R], R2, CO) :-
    esc(EC, CO), 
    R2 := R.
esc([C|R], R2, CO) :- 
    C =\= 0'\\ | R2 := R, CO := C.

esc(0'n, CO) :- CO := 10.
esc(0'r, CO) :- CO := 13.
esc(0't, CO) :- CO := 9.
esc(0'e, CO) :- CO := 27.
esc(C, CO) :- otherwise | CO := C.

hex(R, L, O, E) :-
    hex1(R, BL, R2),
    list_to_bytes(BL, Bytes),
    O := [bytes(L, Bytes)|O2], 
    lex(R2, L, O2, E).

hex1([C|R], BL, R2) :- hexdigit(C, V), hex1(V, C, R, BL, R2).

hex1(V, _, R, BL, R2) :- integer(V) | hex2(R, V, BL, R2).
hex1(_, C, R, BL, R2) :- otherwise | R2 := [C|R], BL := [].

hex2([C|R], Hi, BL, R2) :- hexdigit(C, V), hex2(V, C, R, Hi, BL, R2).

hex2(V, _, R, Hi, BL, R2) :- 
    integer(V) |
    B is (Hi << 4) \/ V,
    BL := [B|BL2],
    hex1(R, BL2, R2).
hex2(_, C, R, Hi, BL, R2) :-
    otherwise | B is Hi << 4, BL := [B], R2 := [C|R].

hexdigit(C, V) :- C >= 0'0, C =< 0'9 | V is C - 0'0.
hexdigit(C, V) :- C >= 0'a, C =< 0'f | V is C - 0'a + 10.
hexdigit(C, V) :- C >= 0'A, C =< 0'F | V is C - 0'A + 10.
hexdigit(_, V) :- otherwise | V := no.
