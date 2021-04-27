% merge test with multiple nodes

-exports([main/0]).
-machine(ring).

main :-
    p([1, 2, 3, 4, 5], O1)@fwd,
    p([a, b, c, d, e], O2)@bwd,
    merger([merge(O1), merge(O2)], R),
    c(R, 0, '`').

p([], O) :- O := [].
p([X|R], O) :- O := [X|O2], p(R, O2).

c([], PN, PS) :- fmt:format('~d/~a\n', [PN, PS]).
c([X|R], PN, PS) :- integer(X), X @> PN | c(R, X, PS).
c([X|R], PN, PS) :- string(X), X @> PS | c(R, PN, X).
c([X|_], PN, PS) :- otherwise | error(unexpected(X, PN, PS)).
