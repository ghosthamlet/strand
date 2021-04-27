% multiple streams merged from many nodes

-exports([main/0]).
-machine(ring).

main :- spawn(10, []).

spawn(0, SS) :- 
    merger(SS, O), consume(O, 0).
spawn(N, SS) :-
    N > 0 | 
    produce(1000, I),
    N2 is N - 1, spawn(N2, [merge(I)|SS])@fwd.

produce(0, I) :- I := [].
produce(N, I) :-
    N > 0 | 
    I := [N|I2],
    N2 is N - 1, 
    produce(N2, I2).

consume([], C) :- 
    writeln(C).
consume([_|S], C) :-
    C2 is C + 1, consume(S, C2).
