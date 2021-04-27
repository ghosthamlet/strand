% 9P utilities

-exports([stat/2, permissions/2, wstat/3, gen_path/1]).

stat(INFO, STAT) :- stat(INFO, [], STAT).

stat([], ALL, STAT) :-
    time(T), 
    gen_path(P),
    merge(ALL, [{0, 0, P}, 0, T, T, 0, '', any, any, any], STAT1),
    list_to_tuple(STAT1, STAT).
stat([d|L], ALL, STAT) :- stat([qid(d)|L], ALL, STAT).
stat([qid(QID)|L], ALL, STAT) :-
    fix_qid(QID, QID2),
    add_stat(ALL, 1, QID2, ALL2), stat(L, ALL2, STAT).
stat([mode(M)|L], ALL, STAT) :-
    add_stat(ALL, 2, M, ALL2), stat(L, ALL2, STAT).
stat([perm(P)|L], ALL, STAT) :-
    permissions(P, PERM),
    add_stat(ALL, 2, PERM, ALL2), stat(L, ALL2, STAT).
stat([atime(T)|L], ALL, STAT) :-
    add_stat(ALL, 3, T, ALL2), stat(L, ALL2, STAT).
stat([mtime(T)|L], ALL, STAT) :-
    add_stat(ALL, 4, T, ALL2), stat(L, ALL2, STAT).
stat([length(N)|L], ALL, STAT) :-
    add_stat(ALL, 5, N, ALL2), stat(L, ALL2, STAT).
stat([name(N)|L], ALL, STAT) :-
    add_stat(ALL, 6, N, ALL2), stat(L, ALL2, STAT).
stat([user(U)|L], ALL, STAT) :-
    add_stat(ALL, 7, U, ALL2), stat(L, ALL2, STAT).
stat([group(G)|L], ALL, STAT) :-
    add_stat(ALL, 8, G, ALL2), stat(L, ALL2, STAT).
stat([modifier(U)|L], ALL, STAT) :-
    add_stat(ALL, 9, U, ALL2), stat(L, ALL2, STAT).

add_stat([], 1, X, RL) :- RL := [X].
add_stat([], N, X, RL) :- 
    N > 1 | 
    RL := [default|RL2], N2 is N - 1, add_stat([], N2, X, RL2).
add_stat([_|L], 1, X, RL) :- RL := [X|L].
add_stat([Y|L], N, X, RL) :- 
    N > 1 | 
    N2 is N - 1, RL := [Y|RL2], add_stat(L, N2, X, RL2).

merge([], L, R) :- R := L.
merge([default|S], [X|L], R) :- R := [X|R2], merge(S, L, R2).
merge([X|S], [_|L], R) :- X =\= default | R := [X|R2], merge(S, L, R2).

fix_qid(f, QID) :- gen_path(P), QID := {0, 0, P}.
fix_qid(d, QID) :- gen_path(P), QID := {16'80, 0, P}.
fix_qid({f, V, P}, QID) :- fix_qid({0, V, P}, QID).
fix_qid({d, V, P}, QID) :- fix_qid({16'80, V, P}, QID).
fix_qid({M, V, P}, QID) :- integer(M) | QID := {M, V, P}.
fix_qid({M, P}, QID) :- fix_qid({M, 0, P}, QID).
fix_qid(P, QID) :- list(P) | QID := {0, 0, P}.

permissions(PERM, P) :-
    string(PERM) | 
    string_to_list(PERM, L, []), 
    permissions(L, 0, P).
permissions(PERM, P) :- integer(PERM) | P := PERM.

permissions([], P1, P) :- P := P1.
permissions([0'd|L], P1, P) :-
    permissions(L, P1, P2),
    P is P2 \/ 16'80000000.
permissions([R, W, X|L], P1, P) :-
    permissions(R, 0'r, 2'100, RP),
    permissions(W, 0'w, 2'010, WP),
    permissions(X, 0'x, 2'001, XP),
    P2 is (P1 << 3) \/ RP \/ WP \/ XP,
    permissions(L, P2, P).

permissions(S, S, B, P) :- P := B.
permissions(0'-, _, _, P) :- P := 0.
permissions(S1, _, _, _) :- 
    otherwise | error(bad_permissions(S1)).

wstat(S1, S2, S) :-
    tuple_to_list(S1, L1, []),
    tuple_to_list(S2, L2, []),
    wstat2(L1, L2, S0),
    list_to_tuple(S0, S).

wstat2([], [], S) :- S := [].
wstat2([-1|S1], [X|S2], S) :- S := [X|S0], wstat2(S1, S2, S0).
wstat2([''|S1], [X|S2], S) :- S := [X|S0], wstat2(S1, S2, S0).
wstat2([X|S1], [QID|S2], S) :- 
    X =\= -1, X =\= '', tuple(QID) | 
    S := [QID|S0], wstat2(S1, S2, S0).
wstat2([X|S1], [_|S2], S) :- otherwise | S := [X|S0], wstat2(S1, S2, S0).

gen_path(P) :-
    time(T),
    S is clock + T,     % XXX find something better
    '$randomize'(S, RND),
    N is (T \/ (clock << 32)) >< (RND /\ 16'ffffff),    % questionable...
    gen_path(8, N, P).

gen_path(0, _, P) :- P := [].
gen_path(N, X, P) :- 
    N > 0 | 
    B is X /\ 16'ff, 
    P := [B|P2], 
    X2 is X >> 8,
    N2 is N - 1, gen_path(N2, X2, P2).
