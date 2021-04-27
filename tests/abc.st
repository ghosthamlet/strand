% 3 nodes, testing several communication directions

-exports([main/0]).
-machine(ring).

main :- 
    try(a, [], D1), 
    try(b, D1, D2), 
    try(c, D2, D3), 
    fini(D3).

fini([]).

try(M, [], R) :- a(M, _, R).

a(M, X, L) :- b(M, X, R)@fwd, a1(M, X, R), L := R.
b(M, X, L) :- c(M, X, R)@fwd, b1(M, X, R), L := R.
c(M, X, R) :- c1(M, X, R).

a1(a, X, _) :- X := a, write(seta(X)).
a1(_, X, []) :- otherwise | write(a(X)).

b1(b, X, _) :- X := b, write(setb(X)).
b1(_, X, []) :- otherwise | write(b(X)).

c1(c, X, R) :- X := c, R := [], write(setc(X)).
c1(_, X, R) :- otherwise | write(c(X)), R := [].
