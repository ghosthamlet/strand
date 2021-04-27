% test suite for builtin operations

-exports([main/0, e/2]).

e(X, Y) :- Y is X * 2.

ok({OK, NOTOK}, S) :- 
    OK2 is OK + 1, S := {OK2, NOTOK}.
notok({OK, NOTOK}, S) :- 
    NOTOK2 is NOTOK + 1, S := {OK, NOTOK2}.

r(_, E, E, S, S2) :- ok(S, S2).
r(T, R, E, S, S2) :- 
    R =\= E | 
    notok(S, S2), writeln(failed(T, R, E)).

eq(T, X, X, E, S, S2) :- r(T, yes, E, S, S2).
eq(T, X, Y, E, S, S2) :- X =\= Y | r(T, no, E, S, S2).
neq(T, X, Y, E, S, S2) :- X =:= Y | r(T, yes, E, S, S2).
neq(T, X, Y, E, S, S2) :- X \=:= Y | r(T, no, E, S, S2).
nne(T, X, Y, E, S, S2) :- X \=:= Y | r(T, yes, E, S, S2).
nne(T, X, Y, E, S, S2) :- X =:= Y | r(T, no, E, S, S2).
gt(T, X, Y, E, S, S2) :- X > Y | r(T, yes, E, S, S2).
gt(T, X, Y, E, S, S2) :- X =< Y | r(T, no, E, S, S2).
lt(T, X, Y, E, S, S2) :- X < Y | r(T, yes, E, S, S2).
lt(T, X, Y, E, S, S2) :- X >= Y | r(T, no, E, S, S2).
ge(T, X, Y, E, S, S2) :- X >= Y | r(T, yes, E, S, S2).
ge(T, X, Y, E, S, S2) :- X < Y | r(T, no, E, S, S2).
le(T, X, Y, E, S, S2) :- X =< Y | r(T, yes, E, S, S2).
le(T, X, Y, E, S, S2) :- X > Y | r(T, no, E, S, S2).
g_known(T, X, E, S, S2) :- known(X) | r(T, yes, E, S, S2).
g_known(T, X, E, S, S2) :- unknown(X) | r(T, no, E, S, S2).
g_data(T, X, E, S, S2) :- data(X), known(X) | r(T, yes, E, S, S2).
g_data(T, X, E, S, S2) :- data(X), unknown(X) | r(T, no, E, S, S2).
g_string(T, X, E, S, S2) :- string(X) | r(T, yes, E, S, S2).
g_string(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_tuple(T, X, E, S, S2) :- tuple(X) | r(T, yes, E, S, S2).
g_tuple(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_integer(T, X, E, S, S2) :- integer(X) | r(T, yes, E, S, S2).
g_integer(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_list(T, X, E, S, S2) :- list(X) | r(T, yes, E, S, S2).
g_list(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_module(T, X, E, S, S2) :- module(X) | r(T, yes, E, S, S2).
g_module(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_port(T, X, E, S, S2) :- port(X) | r(T, yes, E, S, S2).
g_port(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).
g_bytes(T, X, E, S, S2) :- bytes(X) | r(T, yes, E, S, S2).
g_bytes(T, _, E, S, S2) :- otherwise | r(T, no, E, S, S2).

gto(T, X, Y, E, S, S2) :- X @> Y | r(T, yes, E, S, S2).
gto(T, X, Y, E, S, S2) :- X @=< Y | r(T, no, E, S, S2).

report({_, 0}) :-
    writeln('all tests succeeded.').
report({OK, NOTOK}) :-
    writeln(tests_succeeded(OK)),
    writeln(tests_failed(NOTOK)).

main :- 
    S1 := {0, 0}, 
    builtins(S1, S2),
    forms(S2, S2a),
    guards(S2a, S3),
    order(S3, S4),
    exprs(S4, S5),
    misc(S5, S6),
    report(S6).

builtins(S0, S) :-
    string_to_list('', L0, []), list_to_string(L0, A0),
        r(string_to_list_0, A0, '', S0, S1),
    string_to_list(abc, L1, []), list_to_string(L1, A1), 
        r(string_to_list, A1, abc, S1, S2),
    string_to_list('a⎕c', L2, []), list_to_string(L2, A2), 
        r(string_to_list_utf, A2, 'a⎕c', S2, S3),
    string_to_list('abc', L3, [0'd]), list_to_string(L3, A3), 
        r(string_to_list_tail, A3, 'abcd', S3, S4),
    string_to_byte_list('a⎕c', L2b, []), 
        r(string_to_byte_list_utf, L2b, [16'61, 16'e2, 16'8e, 16'95, 16'63], 
            S4, S4b),
    make_tuple(3, T1), length(T1, N3), 
        r(make_tuple, N3, 3, S4b, S5),
    integer_to_list(123, L4), list_to_integer(L4, N4), 
        r(integer_to_list, N4, 123, S5, S6),
    integer_to_list(256, 16, L4x), list_to_integer(L4x, 8, N4x), 
        r(integer_to_list2, N4x, 64, S6, S6x), 
    integer_to_list(256, 16, Li5x, "x"), 
        r(integer_to_list4, Li5x, "100x", S6x, S6y), 
    tuple_to_list({a, b, c}, L5, [d]), list_to_tuple(L5, T5), 
        r(tuple_to_list, T5, {a, b, c, d}, S6y, S7),
    tuple_to_list({}, L5x, []), list_to_tuple(L5x, T5x), 
        r(tuple_to_list, T5x, {}, S7, S7x),
    length({a, b, c}, N6), r(tuple_length, N6, 3, S7x, S8),
    length([a, b, c], N7), r(list_length, N7, 3, S8, S9),
    length(abc, N8), r(string_length, N8, 3, S9, S10),
    length([], N9), r(null_length, N9, 0, S10, S11),
    get_module(builtins, M1), run(M1, e(123, N10)), 
        r(run, N10, 246, S11, S12x),
    run(builtins, e(100, N10x)), r(run2, N10x, 200, S12x, S12),
    assign(N12, 123, L11), r(assign, {N12, L11}, {123, []}, S12, S13),
    make_tuple(3, T13), put_arg(1, T13, abc), put_arg(2, T13, 123),
        put_arg(3, T13, 456, L14), 
        r(put_arg, {T13, L14}, {abc(123, 456), []}, S13, S14),
    get_arg(1, T13, A15), get_arg(2, T13, N16), 
        get_arg(3, T13, N17, L18),
        r(get_arg, {A15, N16, N17, L18}, {abc, 123, 456, []}, S14, S15),
    open_file("test.out", w, F1),
    write_chars(F1, [65, 66, 16'2501, 67]),
    write(F1, 'xyz'),
    close_file(F1),
    time(MT1),
    open_file('test.out', r, F2),
    read_bytes(F2, 100, FL1), bytes_to_list(FL1, FL1a, []), list_to_string(FL1a, FA1),
        r(file, FA1, 'ABâCxyz', S15, S16),
    read_bytes(F2, 100, FL2), bytes_to_list(FL2, FL2a, []), r(file2, FL2a, [], S16, S17),
    utf_decode([65, 66], U1, UL1), r(utf_decode1, U1, 65, S17, S18),
        r(utf_decode2, UL1, [66], S18, S19),
    utf_decode([16'ce, 16'9e, 16'0a], U2, UL2), 
        r(utf_decode3, U2, 926, S19, S20),
        r(utf_decode4, UL2, [10], S20, S21),
    utf_encode(16'2588, UL3, []), r(utf_encode, UL3, [16'e2, 16'96, 16'88], S21, S21a),
    open_pipe(PIN, POUT),
    pipe_test(PIN, POUT, PR),
        r(pipe, PR, [65, 66, 67], S21a, S22),
    shell("exit 123", XS), r(shell, XS, 123, S22, S23),
    file_size('test.out', FS), r(file_size, FS, 9, S23, S24),
    file_modification_time('test.out', MT2), r(file_mtime, MT1, MT2, S24, S25),
    listen_test('test.out', LOK), r(listen, LOK, ok, S25, S26),
    string_to_integer('123', SI1), r(string_to_int, SI1, 123, S26, S27),
    string_to_integer('-123', SI2), r(string_to_int, SI2, -123, S27, S28),
    string_to_integer('1011', 2, SI3), r(string_to_int, SI3, 11, S28, S29),
    file_status(sjdhfdhdhfjh, FST1), 
        r(status_none, FST1, none, S29, S30),
    file_status('tests/builtins.st', FST2), 
        r(status_file, FST2, file, S30, S31),
    file_status("tests", FST3), 
        r(status_dir, FST3, directory, S31, S32),
    put_global(g1, 123, POK), r(put_global, POK, [], S32, S33),
    get_global(g1, GR), r(get_global, GR, 123, S33, S34),
    get_global(xxx, GR2, []), r(get_global_undef, GR2, [], S34, S35),
    deref_test({{{X}}}, X, DRR), r(deref, DRR, [], S35, S36),
    send_test(SP), r(send_port, SP, [1, a, "b"], S36, S37),
    list_to_bytes("XYZAB", B1),
    bytes_to_list(B1, BL0, []), r(bytes_to_list, BL0, "XYZAB", S37, S38),
    '$put_bytes'(1, B1, "abc", PBOK1),
    '$put_bytes'(2, B1, 0'X, PBOK2),
    list_to_bytes([64, 32], BY1),
    '$put_bytes'(4, B1, BY1, PBOK3),
    get_bytes(1, B1, 5, BL1, PBOK1), 
        r(get_bytes, {BL1, PBOK2, PBOK3}, {"aXc@ ", [], []}, S38, S39),
    get_bytes(1, B1, 0, LB1a, []), 
        r(get_0_bytes, LB1a, [], S39, S39a),
    make_bytes(5, 0'A, B2),
    bytes_to_list(B2, BL2, []), r(make_bytes, BL2, "AAAAA", S39a, S40),
    copy_bytes(2, B1, 3, B3), 
        bytes_to_list(B3, BL3, []), r(copy_bytes, BL3, "Xc@", S40, S40a),
    copy_bytes(2, B1, 0, B4), 
        length(B4, LB4), r(copy_0_bytes, LB4, 0, S40a, S40b),
    char_list_to_bytes("αβξ", CLB1),
    bytes_to_char_list(CLB1, LB2, []), r(char_bytes, LB2, "αβξ", S40b, S40d),
    timer_test(S40d, S41),
    pack({[1, 2|3], ok}, PX1), unpack(PX1, UPX1),
        r(pack, UPX1, {[1, 2|3], ok}, S41, S42),
    search_string('abc', "  abc  ", Rsearch1), r(search1, Rsearch1, 3, S42, S43),
    search_string("AB", #004142, Rsearch2), r(search2, Rsearch2, 2, S43, S44),
    search_string('A', 'BC', Rsearch3), r(search3, Rsearch3, 0, S44, S45),
    search_string('A', 'ABCA', 2, Rsearch4), r(search4, Rsearch4, 4, S45, S46),
    S := S46.

forms(S1, S) :-
    open_port(P, PS),
    foreach(X, [1, 2, 5, 0], send(P, X)), sum(PS, R),
        r(foreach, R, 8, S1, S2),
    foreach(_, [], halt(0)),
    L := [_, _, _],
    foreach(X, L, X := 1), r(foreach_var, L, [1, 1, 1], S2, S3),
    when(T, r(when, T, yes, S3, S4)),
    when(T2, (X2 := T2, r(when_2, X2, ok, S4, S))),
    wait(3, T, T2).

wait(0, T, T2) :- T := yes, T2 := ok.
wait(N, T, T2) :- N > 0 | N2 is N - 1, wait(N2, T, T2).

sum([0|_], R) :- R := 0.
sum([X|L], R) :- sum(L, R1), R is X + R1.

guards(S1, S) :-    
    eq(eq1, 123, 123, yes, S1, S2),
    eq(eq2, 123, 124, no, S2, S3),
    eq(eq3, abc, abc, yes, S3, S4),
    eq(eq4, abc, def, no, S4, S5),
    eq(eq5, [] , [], yes, S5, S6), 
    eq(eq6, {a, b} , {a, b}, yes, S6, S7),
    eq(eq7, {a, b} , {a, c}, no, S7, S8), S9 := S8,
    eq(eq8, [a, b] , [a, b], yes, S9, S10),
    eq(eq9, [a, b] , [a, c], no, S10, S11),
    eq(eq10, [a, b] , {a, b}, no, S11, S12),
    eq(eq11, [a, b] , [a], no, S12, S13),
    eq(eq11, [a, b] , [a, b, c], no, S13, S14),
    eq(eq12, {a, b} , {a}, no, S14, S15),
    eq(eq13, {a, b} , {a, b, c}, no, S15, S16),
    gt(gt1, 124, 123, yes, S16, S17),
    gt(gt2, 123, 124, no, S17, S18),
    gt(gt3, 123, 123, no, S18, S19), S20 := S19,
    lt(lt1, 123, 124, yes, S20, S21),
    lt(lt2, 124, 123, no, S21, S22),
    lt(lt3, 123, 123, no, S22, S23),
    ge(ge1, 124, 123, yes, S23, S24),
    ge(ge2, 123, 123, yes, S24, S25),
    ge(ge3, 123, 124, no, S25, S26),
    le(le1, 123, 124, yes, S26, S27),
    le(le2, 123, 123, yes, S27, S28),
    le(le3, 124, 123, no, S28, S29),
    g_known(known, 123, yes, S29, S30),
    g_known(known, _, no, S30, S31),
    g_data(data, 123, yes, S31, S32),
    g_string(string, abc, yes, S32, S33),
    g_string(no_string, 123, no, S33, S34),
    g_string(null_no_string, [], no, S34, S35),
    g_tuple(tuple, {123}, yes, S35, S36),
    g_tuple(no_tuple, 123, no, S36, S37),
    g_tuple(empty_tuple, {}, yes, S37, S38),
    g_tuple(no_null_tuple, [], no, S38, S39),
    g_integer(integer, 123, yes, S39, S40),
    g_integer(no_integer, abc, no, S40, S41),
    g_list(list, [1], yes, S41, S42),
    g_list(no_list, [], no, S42, S43),
    get_module(builtins, M),
    g_module(module, M, yes, S43, S44),
    g_module(no_module, {}, no, S44, S45),
    neq(neq1, 123, 123, yes, S45, S46),
    neq(neq2, 123, 124, no, S46, S47),
    nne(nne1, 123, 123, no, S47, S48),
    nne(nne2, 123, 124, yes, S48, S49),
    open_port(P, _),
    g_port(port, P, yes, S49, S50),
    g_port(no_port, [], no, S50, S51),
    make_bytes(3, B),
    g_bytes(bytes, B, yes, S51, S52),
    g_bytes(no_bytes, [], no, S52, S53),
    S := S53.

order(S1, S) :-
    gto(gto1, 124, 123, yes, S1, S2),
    gto(gto1, 123, 123, no, S2, S3),
    gto(gto3, 123, 124, no, S3, S4),
    gto(gto4, abc, abd, no, S4, S5),
    gto(gto5, abd, abc, yes, S5, S6),
    gto(gto6, abc, abc, no, S6, S7),
    gto(gto7, abcd, abc, yes, S7, S8),
    gto(gto8, abc, abcd, no, S8, S9),
    gto(gto9, {a, c}, {a, b}, yes, S9, S10),
    gto(gto10, {a, b}, {a, b}, no, S10, S11),
    gto(gto11, {a, b}, {a, c}, no, S11, S12),
    gto(gto12, {a, b, c}, {a, b}, yes, S12, S13),
    gto(gto13, {a, b}, {a, b, c}, no, S13, S14),
    gto(gto14, [a|c], [a|b], yes, S14, S15),
    gto(gto15, [a|b], [a|b], no, S15, S16),
    gto(gto16, [a|b], [a|c], no, S16, S17),
    gto(gto17, {a}, [a], yes, S17, S18),
    gto(gto18, [a], a, yes, S18, S19),
    gto(gto19, a, 123, yes, S19, S20),
    gto(gto20, [a], {a}, no, S20, S21),
    gto(gto21, a, [a], no, S21, S22),
    gto(gto22, 123, a, no, S22, S23),
    gto(gto23, {}, [], yes, S23, S24),
    open_port(P, _),
    gto(gto24, P, [1], yes, S24, S25),
    get_module(builtins, M),
    gto(gto25, M, P, yes, S25, S26),
    S := S26.

exprs(S1, S) :-
    R1 is 123 + 1, r(add1, R1, 124, S1, S2),
    R2 is 123 + (-1), r(add2, R2, 122, S2, S3),
    R3 is 123 - 1, r(sub1, R3, 122, S3, S4),
    R4 is 123 - (-1), r(sub2, R4, 124, S4, S5),
    R5 is 123 * 2, r(mul1, R5, 246, S5, S6),
    R6 is 123 * -2, r(mul2, R6, -246, S6, S7),
    R7 is 123 * 1, r(mul3, R7, 123, S7, S8),
    R8 is 123 * 0, r(mul4, R8, 0, S8, S9),
    R9 is 120 / 2, r(div1, R9, 60, S9, S10),
    R10 is 120 / 1, r(div2, R10, 120, S10, S11),
    R11 is 0 / 2, r(div3, R11, 0, S11, S12),
    R12 is 123 \\ 2, r(mod1, R12, 1, S12, S13),
    R12a is -123 \\ 2, r(mod2, R12a, -1, S13, S14),
    R13 is 123 \\ -2, r(mod3, R13, 1, S14, S15),
    R14 is abs(123), r(abs1, R14, 123, S15, S16),
    R15 is abs(-123), r(abs2, R15, 123, S16, S17),
    R16 is abs(0), r(abs3, R16, 0, S17, S18),
    R17 is 2'1101 /\ 2'1001, r(and, R17, 2'1001, S18, S19),
    R18 is 2'1101 \/ 2'1001, r(or, R18, 2'1101, S19, S20),
    R19 is 2'1101 >< 2'1001, r(xor, R19, 2'0100, S20, S21),
    R20 is \2'1101, r(not, R20, -14, S21, S22),
    R21 is 2'11011 >> 1, r(rshift, R21, 2'1101, S22, S23),
    R22 is 2'11011 << 2, r(lshift, R22, 2'1101100, S23, S24),
    R23 is max(1, 2), r(max1, R23, 2, S24, S25),
    R24 is max(1, -2), r(max2, R24, 1, S25, S26),
    R25 is max(3, 3), r(max3, R25, 3, S26, S27),
    R26 is min(1, 2), r(min1, R26, 1, S27, S28),
    R27 is min(1, -2), r(min2, R27, -2, S28, S29),
    R28 is min(3, 3), r(min3, R28, 3, S29, S30),
    N1 := 123,
    R29 is -N1, r(neg, R29, -123, S30, S31),
    S := S31.

misc(S1, S) :-
    builtins:e(100, X), r(call, X, 200, S1, S2),
    merge1(S2, S3),
    merge2(S3, S4),
    S := S4.

merge1(S1, S) :-
    merger(I, O),
    sum(0, 10, 1, I),
    mresult(O, 0, R), r(merge1, R, 55, S1, S).

merge2(S1, S) :-
    merger([merge(I1), merge(I2)], O),
    sum(0, 10, 1, I1),
    sum(100, 150, 5, I2),
    mresult(O, 0, R), r(merge2, R, 1330, S1, S).

sum(START, END, _, S) :- START >= END | S := [].
sum(START, END, STEP, S) :- 
    otherwise | 
    N is START + STEP,
    S := [N|S2],
    sum(N, END, STEP, S2).

mresult([], T, R) :- R := T.
mresult([X|S], T, R) :- T2 is T + X, mresult(S, T2, R).

pipe_test(IN, OUT, R) :-
    write_bytes(OUT, [65, 66, 67], OK),
    pipe_test1(OK, IN, OUT, R).

pipe_test1([], IN, OUT, R) :-
    close_file(OUT),
    read_bytes(IN, 3, R1),
    bytes_to_list(R1, R, []),
    done_close(R, IN).

done_close(X, F) :-
    data(X) | close_file(F).

listen_test(FN, OK) :-
    open_file(FN, r, FD),
    listen(FD, INP),
    time(T1), THEN is T1 + 5,
    listen_wait(0, THEN, FD, INP, OK).

listen_wait(_, _, FD, INP, OK) :-
    known(INP) | 
    close_file(FD), OK := ok.
listen_wait(1000, THEN, FD, INP, OK) :-
    unknown(INP) |
    time(NOW),
    listen_wait2(NOW, THEN, FD, INP, OK).
listen_wait(T, THEN, FD, INP, OK) :-
    unknown(INP) |
    T2 is T + 1,
    listen_wait(T2, THEN, FD, INP, OK).
listen_wait(NOW, THEN, FD, INP, OK) :-
    otherwise |
    % just repeat - wakeup due to listening may be triggered
    % in-between matching attempts...
    listen_wait(NOW, THEN, FD, INP, OK).

listen_wait2(NOW, THEN, FD, _, OK) :-
    NOW >= THEN |
    close_file(FD),
    OK := timeout.
listen_wait2(NOW, THEN, FD, INP, OK) :-
    NOW < THEN |
    listen_wait(0, THEN, FD, INP, OK).

deref_test(X, V, OK) :-
    deref(X, OK1),
    deref_test2(OK1, V, OK).

deref_test2(D, V, OK) :- unknown(D) | V := 123, deref_test3(D, OK).
deref_test3([], OK) :- OK := [].

send_test(S) :- open_port(P, S), send_test(P, S).

send_test(P, S) :- send(P, 1), send_test2(S, P).
send_test2([1|S], P) :- send(P, a), send_test3(S, P).
send_test3([a|S], P) :- send(P, "b"), send_test5(S).
send_test5(["b"|S]) :- '$reclaim'(X, _), send_test6(X, S).
send_test6(X, []) :- data(X) | true.

timer_test(S1, S) :-
    time(T0),
    timer(1500, TM1),
    single_shot(TM1, T0, S1, S).

single_shot([], T0, S1, S) :-
    time(T1), 
    TD is T1 - T0, 
    single_shot(TD, S1, S).

single_shot(T, S1, S) :-
    T >= 1, T =< 3 |
    r(single_shot_timer, T, T, S1, S2),
    time(T0),
    timer(1000, 1500, TM),
    C is clock,
    periodic(TM, 0, C/T0, S2, S).
single_shot(T, S1, S) :-
    otherwise | r(single_shot_timer, T, not_between(1, 3), S1, S).

periodic([], N, _, S1, S) :-
    r(periodic_timer, N, 3, S1, S).
periodic([C|TM], N, C0/T0, S1, S) :-
    C > C0 |
    time(T),
    periodic(TM, T, N, C/T0, S1, S).
periodic([C|_], _, C0/_, S1, S) :-
    r(periodic_timer, C, clock_not_increasing(C0, C), S1, S).

periodic(TM, T, N, C/T0, S1, S) :-
    T > T0 |
    N2 is N + 1,
    periodic2(TM, N2, C/T, S1, S).
periodic(_, T, _, _/T0, S1, S) :-
    T =< T0 |
    r(periodic_timer, T, time_not_increasing(T0), S1, S).

periodic2(TM, 3, C/T, S1, S) :-
    disable_timer,
    periodic(TM, 3, C/T, S1, S).
periodic2(TM, N, C/T, S1, S) :-
    N < 3 | periodic(TM, N, C/T, S1, S).
