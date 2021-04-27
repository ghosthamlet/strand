% verify clause indexing

-exports([main/0]).

main :-
    atom,
    tuple,  
    head.

atom :-
    atom0(1, R0), atom0(R0),
    atom1(1, R1), atom1(2, R2), atom1(3, R3), atom1(4, R4), atom1({R1, R2, R3, R4}),
    atom2(1, 0, R5), atom2(2, 1, R6),
    atom2(3, 2, R7), atom2({R5, R6, R7}),
    atom3(1, R8), atom3(R8).

atom0(1, R) :- R := 0.
atom0(0).

atom1(1, R) :- R := 1. 
atom1(2, R) :- R := 2.
atom1(3, R) :- R := 3.
atom1(_, R) :- R := 4.
atom1({1, 2, 3, 4}).

atom2(1, 0, R) :- R := 1.
atom2(2, 0, R) :- R := 2.
atom2(2, 1, R) :- R := 3.
atom2(3, 2, R) :- R := 4.
atom2({1, 3, 4}).

atom3(1, R) :- R := 1.
atom3({}, R) :- R := 2.
atom3(1).

tuple :-
    tuple0({}, R1), tuple0(R1),
    tuple1({x}, R2), tuple1(R2),
    tuple2({x}, 1, R3), tuple2({99}, 2, R4), tuple2({[]}, 3, R5), tuple2({z, 1}, 4, R6), 
        tuple2(R3, R4, R5, R6),
    tuple3(x/1, R7), tuple3(y/1, R8), tuple3({}, R9), tuple3({[]}, R10), tuple3({[1]}, R11), 
        tuple3({a}, R12), tuple3(R7, R8, R9, R10, R11, R12).

tuple0({}, R) :- R := 1.
tuple0(1).

tuple1({x}, R) :- R := 2.
tuple1(2).

tuple2({x}, 1, R) :- R := 1.
tuple2({99}, 2, R) :- R := 2.
tuple2({[]}, 3, R) :- R := 3.
tuple2({z, 1}, 4, R) :- R := 4.
tuple2(1, 2, 3, 4).

tuple3(x/1, R) :- R := 1.
tuple3(y/1, R) :- R := 2.
tuple3({}, R) :- R := 3.
tuple3({[]}, R) :- R := 4.
tuple3({[1]}, R) :- R := 5.
tuple3(_, R) :- R := 6.
tuple3(1, 2, 3, 4, 5, 6).

head :-
    head0([1], R1), head0(R1),
    head1([1], 1, R6), head1([2], 2, R7), head1(R6, R7),
    head2([1], R2), head2([2], R3), head2([3], R4), head2([4], R5), head2(R2, R3, R4, R5),
    head3([a,b], R8), head3([1], R9), head3([x(y)], R10), head3([xxx], R11),
        head3([{}], R12), head3([[]], R13), head3([99,100], R14),
        head3(R8, R9, R10, R11, R12, R13, R14).

head0([1], R) :- R := 1.
head0(1).

head1([1], 0, R) :- R := 1.
head1([1], 1, R) :- R := 2.
head1([2], 2, R) :- R := 3.
head1(2, 3).

head2([1], R) :- R := 1.
head2([2], R) :- R := 2.
head2([3], R) :- R := 3.
head2([X], R) :- R := X.
head2(1, 2, 3, 4).

head3([a, b], R) :- R := 1.
head3([{}], R) :- R := 2.
head3([[]], R) :- R := 3.
head3([1], R) :- R := 4.
head3([foo(1)|_], R) :- R := 5.
head3([x(y)|_], R) :- R := 6.
head3([_|_], R) :- R := 7.
head3(1, 4, 6, 7, 2, 3, 7).
