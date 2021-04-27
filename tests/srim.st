% send/receiver with incomplete messages
%
% from: "Parallel Logic Programming Techniques" (S. Taylor)

-exports([main/0]).
-machine(ring).

main :-
    sender(200, S), 
    receiver(S, 0)@fwd.

sender(N, S) :-
    N > 0 |
    N1 is N - 1,
    sender(N1, S2),
    get_reply(R),
    S := [msg(R)|S2].
sender(0, S) :- S := [].

receiver([msg(R)|S], N) :-
    N1 is N + 1,
    receiver(S, N1),
    R := ok.
receiver([], N) :- 
    writeln(N),
    done(N)@bwd.

get_reply(ok).

done(N) :- data(N) | true.
