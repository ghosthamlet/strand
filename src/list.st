% lists
%
%     list:append(LIST1?, LIST2?, RESULT^)
%       Appends two lists and assigns the result to RESULT.
%
%     list:append(LISTS?, RESULT^)
%       Concatenates list of lists and assigns result to RESULT.
% 
%     list:delete(VAL?, LIST?, RESULT^)
%       Removes elements matching VAL in LIST and assigns the result
%       to RESULT.
% 
%     list:count(VAL?, LIST^, COUNT^)
%       Counts the values in LIST that match VAL and assign the
%       count to COUNT.
% 
%     list:reverse(LIST?, REV^)
%       Reverse LIST and assign the result to REV.
% 
%     list:reverse(LIST?, TAIL?, REV^)
%       Reverse LIST, the tail of the reversed result will be TAIL.
%
%     list:split(LIST?, SEP?, RESULT^, TAIL?)
%       Splits the list into sublists, separated by SEP.
%
%     list:join(LISTS?, SEP?, RESULT^, TAIL^)
%       Joins the lists in LISTS, with SEP as the separator, which must be a list.
%       RESULT will be assigned the result list, terminated with TAIL.
%
%     list:trim(LIST?, X?, RLIST^)
%     list:trim_left(LIST?, X?, RLIST^)
%     list:trim_right(LIST?, X?, RLIST^)
%       Remove elements equal to X from left, right or both ends,
%       assigning the result to RLIST.
%
%     list:scan(LIST?, X?, RLIST^, TAIL^)
%       Collect elements of LIST in RLIST until the end of LIST or element 
%       occurs X and assign remaining elements to TAIL.
%
%     list:take(N?, LIST?, RLIST^, TAIL?)
%       Takes N successive elements from LIST and assigns the resulting
%       list to RLIST. RLIST will be terminated with TAIL.
%       If LIST has less than N elements, an error will be signalled.
%
%     list:drop(N?, LIST?, RLIST^)
%       Drops N successive elements from LIST, assigning the result to RLIST.
%       If LIST has less than N elements, an error will be signalled.
%
%     list:cut(N?, LIST?, TAIL?, RLIST^, NLIST^)
%       Takes N successive elements from LIST and assigns the resulting list
%       to RLIST. RLIST will be terminated with TAIL. The remainder of LIST
%       after removing the first N elements will be assigned to NLIST.
%       If LIST has less than N elements, an error will be signalled.
%
%     list:assoc(LIST?, X?, DEFAULT?, RESULT^)
%       Searches for a tuple with element 1 being X in LIST. If found, assigns the
%       list-element to RESULT, if not found, assigns DEFAULT.
%
%     list:find(X?, LIST?, RESULT^)
%       Searches for X in LIST and assigns the first matching sublist to RESULT.
%       If X can not be found, the empty list is assigned to RESULT.
%
%     list:pad_left(LENGTH?, X?, LIST?, RLIST^)
%     list:pad_right(LENGTH?, X?, LIST?, RLIST^)
%       Add new elements containing X to the left or right end of LIST and
%       assign the result to RLIST so that the resulting list has at most LENGTH
%       elements. If LIST is already longer than LENGTH, RLIST will be the
%       same as LIST.
%
%     list:times(LENGTH?, X?, LIST^)
%     list:times(LENGTH?, X?, LIST^, TAIL?)
%       Create a list of LENGTH elements containing X and assign it to LIST.
%       If TAIL is given, it is used as the tail of LIST.
%
%     list:make(LENGTH?, LIST^)
%     list:make(LENGTH?, LIST^, TAIL?)
%       Create a list of LENGTH unbound variables, optionally with tail.
%
%     list:last(LIST?, RESULT^)
%       Assigns the last element of LIST to RESULT and produces an error if LIST
%       is empty.
%   
%     list:search(SUBLIST?, LIST?, RESULT^)
%       Searches for the non-empty list SUBLIST in LIST and assigns the first found 
%       sublist to RESULT or the empty list, if not found.

reverse(List, Reversed) :- reverse(List, [], Reversed).

reverse([], Reversed, R) :- R := Reversed.
reverse([Head|Tail], Sofar, Reversed) :-
    reverse(Tail, [Head|Sofar], Reversed).

append([], L, R) :- R := L.
append([X|T], L, R) :- append(T, L, R2), R := [X|R2].

append([], R) :- R := [].
append([L1|LS], R) :-
    append(L1, T, R),
    append(LS, T).

delete(_, [], L) :- L := [].
delete(X, [X|R], L) :- delete(X, R, L).
delete(X, [Y|R], L) :- otherwise | L := [Y|L2], delete(X, R, L2).

count(X, L, R) :- count1(L, X, 0, R).

count1([], _, R1, R) :- R := R1.
count1([X|L], X, R1, R) :- R2 is R1 + 1, count1(L, X, R2, R).
count1([_|L], X, R1, R) :- otherwise | count1(L, X, R1, R).

unique(S, L, UL) :- unique1(S, L, [], UL).

unique1([], _, UL1, UL) :- UL := UL1.
unique1([X|R], L, UL1, UL) :-
    unique2(L, X, UL1, UL2),
    unique1(R, L, UL2, UL).

unique2([X|R], X, UL1, UL) :- unique3(R, X, UL1, UL).
unique2([Y|R], X, UL1, UL) :- X =\= Y | unique2(R, X, UL1, UL).

unique3([], X, UL1, UL) :- UL := [X|UL1].
unique3([X|_], X, UL1, UL) :- UL := UL1.
unique3([Y|R], X, UL1, UL) :- X =\= Y | unique3(R, X, UL1, UL).

head([X|_], R) :- R := X.
tail([_|L], TL) :- TL := L.

pair([X|Y], XR, YR) :- XR := X, YR := Y.

assoc([], _, D, F) :- F := D.
assoc([T|R], X, D, F) :- get_arg(1, T, Y), assoc1(Y, T, R, X, D, F).

assoc1(X, T, _, X, _, F) :- F := T.
assoc1(Y, _, R, X, D, F) :- X =\= Y | assoc(R, X, D, F).

split(L, S, R, T) :- split1(L, S, R, T).

split1([], _, R, T) :- R := T.
split1([S|L], S, R, T) :- 
    R := [[]|T2],
    split1(L, S, T2, T).
split1([X|L], S, R, T) :-
    X =\= S |
    R := [[X|IT]|T2],
    split2(L, S, IT, T2, T).

split2([], _, IT, R, T) :-
    IT := [],
    R := T.
split2([S|L], S, IT, R, T) :-
    IT := [],
    R := [IT2|T2],
    split2(L, S, IT2, T2, T).
split2([X|L], S, IT, R, T) :-
    X =\= S |
    IT := [X|IT2],
    split2(L, S, IT2, R, T).

trim_left([X|L], X, R) :-
    trim_left(L, X, R).
trim_left(L, _, R) :-
    otherwise | R := L.

trim_right([], _, R) :- R := [].
trim_right([X], X, R) :- R := [].
trim_right([X|L], Y, R) :-
    X =\= Y |
    R := [X|R2],
    trim_right(L, Y, R2).
trim_right([X|L], X, R) :-
    L =\= [] |
    trim_right(L, X, R2),
    trim_right1(R2, X, R).

trim_right1([], _, R) :- R := [].
trim_right1(R2, X, R) :-
    R2 =\= [] | R := [X|R2].

trim(X, S, R) :-
    trim_left(X, S, R2),
    trim_right(R2, S, R).

scan([], _, V, R) :- V := [], R := [].
scan([D|R], D, V, R2) :- V := [], R2 := R.
scan([C|R], D, V, R2) :- 
    C =\= D | V := [C|V2], scan(R, D, V2, R2).

take(0, _, R, T) :- R := T.
take(_, [], R, T) :- R := T.
take(N, [X|L], R, T) :- 
    N > 0 | 
    N2 is N - 1, R := [X|R2], take(N2, L, R2, T).

drop(0, L, R) :- R := L.
drop(_, [], R) :- R := [].
drop(N, [_|L], R) :- N > 0 | N2 is N - 1, drop(N2, L, R).

cut(0, L, T, R, RL) :- R := T, RL := L.
cut(N, [X|L], T, R, RL) :- 
    N > 0 | 
    N2 is N - 1, R := [X|R2], cut(N2, L, T, R2, RL).

pad_left(W, X, L, R) :-
    length(L, LEN),
    PW is W - LEN,
    times(PW, X, R, L).

pad_right(W, X, L, R) :-
    length(L, LEN),
    PW is W - LEN,
    times(PW, X, L),
    append(L, PW, R).

times(N, X, L) :- times(N, X, L, []).

times(N, X, L, TL) :-
    N > 0 |
    L := [X|L2],
    N2 is N - 1,
    times(N2, X, L2, TL).
times(_, _, L, TL) :- otherwise | L := TL.

make(N, X) :- make(N, X, []).

make(0, L, TL) :- L := TL.
make(N, L, TL) :-
    L := [_|L2], N2 is N - 1,
    make(N2, L2, TL).

last([X], R) :- R := X.
last([_|L], R) :- last(L, R).

find(_, [], R) :- R := [].
find(X, [X|L], R) :- R := [X|L].
find(X, [Y|L], R) :- X =\= Y | find(X, L, R).

search(_, [], R) :- R := [].
search([X|S], [X|L], R) :- search(S, L, S, X, L, R).
search([X|S], [Y|L], R) :- X =\= Y | search([X|S], L, R).

search([], _, _, Y, L, R) :- R := [Y|L].
search(_, [], _, _, _, R) :- R := [].
search([X|S1], [X|L1], S, Y, L, R) :- search(S1, L1, S, Y, L, R).
search([X1|_], [X|_], S, Y, L, R) :- X1 =\= X | search([Y|S], L, R).

join([], _, R, T) :- R := T.
join([L], _, R, T) :- append(L, T, R).
join([L|Ls], S, R, T) :-
    append([L, S, T1], R),
    join(Ls, S, T1, T).
