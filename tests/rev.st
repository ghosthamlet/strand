% naive reverse

-exports([main/0]).

append([], Ys, Z) :- 
    Z := Ys.
append([X|Xs], Ys, Z) :-
    append(Xs, Ys, Z2),
    Z := [X|Z2].

rev([], Y) :- 
    Y := [].
rev([X|Xs], Y) :-
    rev(Xs, Ys),
    append(Ys, [X], Y).

main :- rev([1,2,3,4,5,6,7,8,9,10], R), writeln(R).
