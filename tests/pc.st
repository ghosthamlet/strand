% producer/consumer (via tunnel)
%
% Run like this:
%
%  strand run tests/tunnel 'remote: 42 <host> 1'
%
% "<host>" should be a machine where Strand is installed and
% the "strand" script is available in the PATH when connecting via
% ssh(1).

-exports([main/0]).
-machine(ring).

main :-
    s_producer(100, S),
    s_consumer(0, 0, S)@fwd.

done(Count, Sum) :-
    fmt:format('sum(~d) = ~d~n', [Count, Sum]).

s_producer(N, Out) :-
    N > 0 |
    R is isqrt(N << 16),
    Out := [R|Out1],
    N1 is N - 1,
    s_producer(N1, Out1).
s_producer(0, Out) :- Out := [].

s_consumer(Sum, Count, [Val|In1]) :-
    Sum1 is Sum + Val,
    Count1 is Count + 1,
    s_consumer(Sum1, Count1, In1).
s_consumer(Sum, Count, []) :-
    done(Count, Sum)@bwd.
