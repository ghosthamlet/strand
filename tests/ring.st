% pass token through ring of arbitrary number of nodes

-exports([main/0]).
-machine(ring).

main :- 
    current_node(First),
    pass(0, First).

pass(4, _).
pass(Cycle, First) :-
    Cycle < 4 | 
    current_node(Self),
    pass(Cycle, First, Self).

pass(Cycle, First, First) :-
    C2 is Cycle + 1,
    blip(C2, First, First).
pass(Cycle, First, Self) :-
    First =\= Self |
    blip(Cycle, First, Self).

blip(Cycle, First, Self) :-
    fmt:format("(~d: #~d)\n", [Self, Cycle], Ok),
    next(Ok, Cycle, First).

next([], Cycle, First) :-
    pass(Cycle, First)@fwd.
