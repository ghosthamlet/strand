% producer/consumer with bounded buffer of length 10

-exports([main/0]).
-machine(ring).

main :-
    list:make(10, L, T),
    s_producer(100, L, S),
    s_consumer(0, 0, S, T)@fwd.

done(Count, Sum) :-
    fmt:format(1, 'sum(~d) = ~d~n', [Count, Sum]).

s_producer(N, [R|L], Out) :-
    N > 0 |
    R is isqrt(N << 16),
    Out := [R|Out1],
    N1 is N - 1,
    s_producer(N1, L, Out1).
s_producer(0, _, Out) :- Out := [].

s_consumer(Sum, Count, [Val|In1], T) :-
    Sum1 is Sum + Val,
    Count1 is Count + 1,
    T := [_|T2],
    s_consumer(Sum1, Count1, In1, T2).
s_consumer(Sum, Count, [], _) :-
    done(Count, Sum)@bwd.
