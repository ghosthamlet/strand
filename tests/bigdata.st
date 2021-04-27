% transfer large amount of data

-exports([main/0]).
-machine(ring).

main :-
    C := 100000,
    p(C, R)@fwd,
    c(R, C).

p(0, R) :- R := [].
p(N, R) :-
    N > 0 |
    N2 is N - 1,
    R := [N|R2],
    p(N2, R2).

c([], 0) :- writeln(done).
c([N|R], N) :-
    N2 is N - 1,
    c(R, N2).
