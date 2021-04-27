% AVL trees
%
% Improved on:
% https://two-wrongs.com/purely-functional-avl-trees-in-common-lisp.html
%
%   map:node(KEY?, VAL?, TREE^)
%       Create a new TREE with a single entry.
%
%   map:insert(KEY?, VAL?, TREE?, RTREE^)
%       Insert new entry into TREE, assigning the new tree to RTREE.
%       If KEY already exists, the existing node is replaced.
%
%   map:delete(KEY?, TREE?, [VAL^, ]RTREE^)
%       Delete entry from TREE and assign new tree to RTREE, optionally
%       assigning old existing value (or {}) to VAL.
%
%   map:replace(KEY?, VAL?, TREE?, RTREE)
%   map:replace(KEY?, VAL?, TREE?, OLDVAL^, RTREE^)
%   map:replace(KEY?, VAL?, TREE?, OLDVAL^, RTREE^, DONE^)
%       Replace existing entry in TREE with new value, optionally assigning
%       the old value (or {}) to OLDVAL. RTREE holds the final result tree.
%       DONE is assigned the empty list when OLDVAL has been bound.
%
%   map:lookup(KEY?, TREE?, VAL^)
%       Assigns the value for the entry with the given KEY in TREE to VAL,
%       assigns {} if no such entry exists.
%
%   map:keys(TREE?, KEYS^)
%       Collects the keys of all entries and assigns the list of keys to KEYS.
%
%   map:values(TREE?, VALS^)
%       Collect the values of all entries and assigns the list to VALS.

-exports([node/3, insert/4, delete/3, delete/4, height/2]).
-exports([replace/4, replace/5, replace/6, lookup/3, keys/2, values/2]).

height({}, H) :- H := 0.
height({H0, _, _, _, _}, H) :- H := H0.

balance({}, B) :- B := 0.
balance({_, _, _, L, R}, B) :-
    height(L, HL), height(R, HR), B is HR - HL.

rotate_l({_, K, V, L, {_, KR, VR, LR, RR}}, T) :-
    node(K, V, L, LR, T1),
    node(KR, VR, T1, RR, T).

rotate_r({_, K, V, {_, KL, VL, LL, RL}, R}, T) :-
    node(K, V, RL, R, T1),
    node(KL, VL, LL, T1, T).

node(K, V, T) :- node(K, V, {}, {}, T).

node(K, V, L, R, T) :-
    height(L, HL), height(R, HR), B is HR - HL,
    H is 1 + max(HL, HR),
    node2(B, H, K, V, L, R, T).

node2(-2, H, K, V, L, R, T) :-
    balance(L, BL),
    node_il(BL, H, K, V, L, R, T).
node2(2, H, K, V, L, R, T) :-
    balance(R, BR),
    node_ir(BR, H, K, V, L, R, T).
node2(_, H, K, V, L, R, T) :- 
    otherwise | T := {H, K, V, L, R}.

node_il(N, H, K, V, L, R, T) :- 
    N < 0 |
    rotate_r({H, K, V, L, R}, T).
node_il(N, _, K, V, L, R, T) :- 
    N > 0 |
    rotate_l(L, L1),
    node(K, V, L1, R, T).
node_il(0, H, K, V, L, R, T) :-
    T := {H, K, V, L, R}.

node_ir(N, _, K, V, L, R, T) :- 
    N < 0 |
    rotate_r(R, R1),
    node(K, V, L, R1, T).
node_ir(N, H, K, V, L, R, T) :- 
    N > 0 |
    rotate_l({H, K, V, L, R}, T).
node_ir(0, H, K, V, L, R, T) :-
    T := {H, K, V, L, R}.

insert(K, V, {}, T) :- 
    node(K, V, T).
insert(K, V, {_, KT, VT, L, R}, T) :-
    K @< KT |
    insert(K, V, L, TL),
    node(KT, VT, TL, R, T).
insert(K, V, {_, KT, VT, L, R}, T) :-
    K @> KT |
    insert(K, V, R, TR),
    node(KT, VT, L, TR, T).
insert(K, V, {_, _, _, L, R}, T) :-
    otherwise | node(K, V, L, R, T).

delete(K, T1, T) :- delete(K, T1, _, T).

delete(_, {}, V, T) :- T := {}, V := {}.
delete(K, {_, KT, VT, L, R}, V, T) :-
    K @< KT |
    delete(K, L, V, TL),
    node(KT, VT, TL, R, T).
delete(K, {_, KT, VT, L, R}, V, T) :-
    K @> KT |
    delete(K, R, V, TR),
    node(KT, VT, L, TR, T).
delete(_, {_, _, V1, L, R}, V, T) :-
    otherwise | 
    V := V1, delete2(L, R, T).

delete2({}, R, T) :- T := R.
delete2(L, {}, T) :- T := L.
delete2(L, R, T) :-
    otherwise |
    min_node(R, MR),
    delete3(MR, L, R, T).

delete3({_, K, V, _, _}, L, R, T) :-
    delete(K, R, DR),
    node(K, V, L, DR, T).

min_node({H, K, V, {}, R}, T) :- T := {H, K, V, {}, R}.
min_node({_, _, _, L, _}, T) :- otherwise | min_node(L, T).

replace(K, V, T1, T) :- replace1(T1, K, V, _, T, _).

replace(K, V, T1, V0, T) :- replace1(T1, K, V, V0, T, _).

replace(K, V, T1, V0, T, OK) :- replace1(T1, K, V, V0, T, OK).

replace1({}, _, _, V0, T, OK) :- 
    T := {}, V0 := {}, OK := [].
replace1({H, K1, V1, L, R}, K, V, V0, T, OK) :-
    K1 @> K | 
    replace1(L, K, V, V0, L1, OK),
    T := {H, K1, V1, L1, R}.
replace1({H, K1, V1, L, R}, K, V, V0, T, OK) :-
    K1 @< K | 
    replace1(R, K, V, V0, R1, OK),
    T := {H, K1, V1, L, R1}.
replace1({H, K, V1, L, R}, _, V, V0, T, OK) :- 
    otherwise | 
    assign(V0, V1, OK), T := {H, K, V, L, R}.

lookup(_, {}, X) :- X := {}.
lookup(K1, {_, K, _, L, _}, X) :-
    K1 @< K | lookup(K1, L, X).
lookup(K1, {_, K, _, _, R}, X) :-
    K1 @> K | lookup(K1, R, X).
lookup(_, {_, _, V, _, _}, X) :- X := V.

keys(T, KS) :- keys(T, KS, []).

keys({}, KS, TL) :- KS := TL.
keys({_, K, _, L, R}, KS, TL) :-
    KS := [K|KS2],
    keys(L, KS2, KS3),
    keys(R, KS3, TL).

values(T, VS) :- values(T, VS, []).

values({}, VS, TL) :- VS := TL.
values({_, _, V, L, R}, VS, TL) :-
    VS := [V|VS2],
    values(L, VS2, VS3),
    values(R, VS3, TL).
