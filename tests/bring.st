% distributed communication stress test:
% produce stream of C numbers and consume in next peer
% in ring of N nodes, spinning for a random amount of time
% between sending a number.

-exports([main/0]).
-machine(ring).

main :- spawn(10, 10, 500)@fwd.

spawn(0, _, _).
spawn(N, SEED, C) :-
    N > 0 |
    SEED2 is SEED * N, rnd:pseudo_random_state(SEED2, RS),
    p(C, RS, S), c(S, C)@fwd, 
    N2 is N - 1, spawn(N2, SEED, C)@fwd.

p(C, RND, S) :- p(C, [], RND, S).

p(0, _, _, S) :- S := [].
p(N, [], RS, S) :-
    N > 0 | 
    rnd:pseudo_random_integer(RS, 100, RND, RS2),
    spin(RND, OK),
    S := [N|S2], N2 is N - 1, p(N2, OK, RS2, S2).

spin(0, OK) :- OK := [].
spin(N, OK) :- N > 0 | N2 is N - 1, spin(N2, OK).

c([], 0) :- current_node(SELF), writeln(SELF).
c([N|S], N) :- N2 is N - 1, c(S, N2).
