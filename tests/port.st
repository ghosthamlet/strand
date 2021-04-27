% port tests

-exports([main/0]).
-machine(ring).

main :-
    open_port(P, S),
    c(S, R),
    check(R),
    p1(P, OK1)@fwd,
    p2(P, OK2),
    p3(P, OK3)@bwd,
    fini(OK1, OK2, OK3).

fini([], [], []) :- write('\n').

check(R) :-
    set:difference([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, a, b, c, d, e, f, g, h, i, j,
        {a}, {b}, {c}, {d}, {e}, {f}, {g}, {h}, {i}, {j}], R, D),
    check2(D).

check2([]).

c([], R) :- R := [].
c([X|S], R) :- write(X), R := [X|R2], c(S, R2).

p1(P, OK) :- p([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], P, OK).
p2(P, OK) :- p([a, b, c, d, e, f, g, h, i, j], P, OK).
p3(P, OK) :- p([{a}, {b}, {c}, {d}, {e}, {f}, {g}, {h}, {i}, {j}], P, OK).

p([], _, OK) :- OK := [].
p([X|R], P, OK) :- send(P, X), p(R, P, OK).
