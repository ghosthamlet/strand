-exports([main/0]).

main :- create(100).

create(0).
create(N) :- 
    N > 0 | 
    C is 33 + N, spin(0, C), 
    N2 is N - 1, create(N2).

spin(I, C) :- I2 is I + 1, F is I \\ 1000, alloc(F, [I2], C).
alloc(0, [I], C) :- write_bytes(1, [C]), spin(I, C).
alloc(_, [I], C) :- spin(I, C).
