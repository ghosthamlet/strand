% draw an AVL tree with ezd(1)

-exports([draw/3]).

draw(T, F, FD) :-
    map:height(T, H),
    N is F * (1 << (H - 1)),
    XO is F * (1 << H),
    fmt:format("(origin ezd ezd ~d 40)\n", [XO], M1),
    output([M1|O1], FD),
    walk1(T, 0, 0, N, -1, -1, O1, O2),
    walk2(T, 0, 0, N, O2, []).

output([], _).
output([S|M], FD) :-
    write_chars(FD, S, OK),
    output(OK, M, FD).

output([], M, FD) :- output(M, FD).

walk1({}, _, _, _, _, _, OS, OT) :- OS := OT.
walk1({_, _, _, L, R}, X, Y, N, UX, UY, OS, OT) :-
    draw_line(X, Y, UX, UY, OS, OT1),
    Y2 is Y + 40,
    XL is X - N,
    N2 is N >> 1,
    walk1(L, XL, Y2, N2, X, Y, OT1, OT2),
    XR is X + N,
    walk1(R, XR, Y2, N2, X, Y, OT2, OT).

walk2({}, _, _, _, OS, OT) :- OS := OT.
walk2({_, K, V, L, R}, X, Y, N, OS, OT) :-
    fmt:format_chars("~q: ~q", [K, V], M),
    draw_object(X, Y, M, OS, OT1),
    Y2 is Y + 40,
    XL is X - N,
    N2 is N >> 1,
    walk2(L, XL, Y2, N2, OT1, OT2),
    XR is X + N,
    walk2(R, XR, Y2, N2, OT2, OT).

draw_object(X, Y, T, O1, O) :-
    fmt:format_chars("(object n~d_~d ", [X, Y], M1),
    PX is X - 10, PY is Y - 10,
    fmt:format_chars("(fill-arc ~d ~d 20 20 0 360 red) ", [PX, PY], M2),
    TX is PX + 20,
    fmt:format_chars("(text ~d ~d \"~s\"))\n", [TX, PY, T], M3),
    O1 := [M1, M2, M3|O].

draw_line(_, _, -1, -1, O1, O) :- O1 := O.
draw_line(X, Y, PX, PY, O1, O) :- 
    otherwise | 
    fmt:format_chars("(line ~d ~d ~d ~d)\n", [X, Y, PX, PY], M),
    O1 := [M|O].
