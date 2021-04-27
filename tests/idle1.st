% test "idle" guard on single node

-exports([main/0]).

main :-
    one, two, three.

one :- idle | write(one).
two :- idle | write(two).

three :- spin(10).

spin(0) :- write(spun), one.
spin(N) :- N > 0 | write('.'), N2 is N - 1, spin(N2).
