% Adapted from: SORTS.PL, by R.A.O'Keefe
%
%     sort:sort(LIST?, RESULT^)
%       Sorts the terms in LIST in term order, ascending and assign
%       the result to RESULT.
% 
%     sort:merge(LIST1?, LIST2?, RESULT^)
%       Merge the sorted lists and assign the sorted result to
%       RESULT.

-exports([sort/2, merge/3]).

sort([], R) :- R := [].
sort([X], R) :- R := [X].
sort([X,Y|L], Sorted) :-
    halve(L, [Y|L], Front, Back),
    sort([X|Front], F),
    sort(Back, B),
    merge(F, B, Sorted).

halve([_,_|Count], [H|T], F2, B) :-
    F2 := [H|F],
    halve(Count, T, F, B).
halve(_, B, F, B2) :-
    otherwise | F := [], B2 := B.

merge([H1|T1], [H2|T2], M) :- 
    M := [Hm|Tm],
    merge1(H1, T1, H2, T2, Hm, Tm).
merge([], L, M) :- M := L.
merge(L, [], M) :- M := L.

merge1(H1, T1, H2, T2, Hm, Tm) :-
    H1 @< H2 |
    Hm := H1, merge(T1, [H2|T2], Tm).
merge1(H1, T1, H2, T2, Hm, Tm) :-
    H1 @> H2 |
    Hm := H2, merge([H1|T1], T2, Tm).
merge1(H1, T1, _, T2, Hm, Tm) :-
    otherwise |
    Hm := H1, merge(T1, T2, Tm).
