% Short circuit test
%
% from: "Parallel Logic Programming Techniques" (S. Taylor)

-exports([main/0]).
-machine(ring).

main :-
    network(100, _, done, AllDone),
    writeln(AllDone).

network(N, Go, Left, Right) :-
    N > 0 |
    N1 is N - 1,
    link(Go, Left, Middle),
    network(N1, Go, Middle, Right)@fwd.
network(0, Go, C1, C2) :- 
    link(Go, C1, C2),
    Go := go.

link(go, C1, C2) :- C2 := C1.
