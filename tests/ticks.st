% measure ticks/second

-exports([main/0]).

main :- 
    time(T),
    C is clock,
    spin(0, T, C, 0).

spin(100, T, C, MAX) :- 
    time(T2),
    spin1(T2, T, C, MAX).
spin(N, T, C, MAX) :-
    N < 100 |
    N2 is N + 1,
    spin(N2, T, C, MAX).

spin1(T, T, C, MAX) :-
    spin(0, T, C, MAX).
spin1(T1, T2, C, MAX) :-
    T1 > T2 |
    N is clock - C,
    spin2(N, MAX, T1).

spin2(N, MAX, _) :-
    N =< MAX |
    platform(OS, ARCH),
    fmt:format(' ~d (~a/~a) ~n', [N, OS, ARCH]).
spin2(N, MAX, T) :-
    N > MAX |
    C is clock,
    spin(0, T, C, N).
