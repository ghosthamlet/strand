% lists as sets
%
%     set:difference(SET1?, SET2?, RESULT^)
%       Computes the set-difference of removing SET2 from SET1.
% 
%     set:intersection(SET1?, SET2?, RESULT^)
%       Computes the intersection of the two lists.
% 
%     set:union(SET1?, SET2?, RESULT^)
%       Computes the union of the two lists.
%

-exports([intersection/3, union/3, difference/3]).

intersection(L1, L2, LI) :- intersection(L1, L2, [], LI).

intersection([], _, LI1, LI) :- LI := LI1.
intersection([X|R], L, LI1, LI) :- 
    intersection1(L, X, LI1, LI2),
    intersection(R, L, LI2, LI).

intersection1([], _, LI1, LI) :- LI := LI1.
intersection1([X|_], X, LI1, LI) :- LI := [X|LI1].
intersection1([_|R], X, LI1, LI) :- 
    otherwise | intersection1(R, X, LI1, LI).

union(L1, L2, LU) :- union(L1, L2, L2, LU).

union([], _, LU1, LU) :- LU := LU1.
union([X|R], L, LU1, LU) :-
    adjoin(L, X, LU1, LU2),
    union(R, L, LU2, LU).

adjoin([], X, LU1, LU) :- LU := [X|LU1].
adjoin([X|_], X, LU1, LU) :- LU := LU1.
adjoin([_|R], X, LU1, LU) :- 
    otherwise | adjoin(R, X, LU1, LU).

difference(L1, L2, LD) :- difference(L1, L2, [], LD).

difference([], _, LD1, LD) :- LD := LD1.
difference([X|R], L, LD1, LD) :-
    adjoin(L, X, LD1, LD2),
    difference(R, L, LD2, LD).
