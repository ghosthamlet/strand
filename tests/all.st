% broadcast test

-exports([main/0]).

main :-
    sys:nodes(ALL),
    open_port(ME, S),
    ping(ME)@all,
    gather(S, [], ALL).

ping(P) :- current_node(ADDR), send(P, ADDR).

gather([A|S], SEEN, ALL) :-
    SEEN2 := [A|SEEN],
    set:difference(ALL, SEEN2, D),
    gather(D, S, SEEN2, ALL).

gather([], _, _, ALL) :- writeln(ALL).
gather(D, S, SEEN, ALL) :-
    list(D) | gather(S, SEEN, ALL).
