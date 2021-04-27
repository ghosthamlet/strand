% Operations on Strand terms

% extract term arguments from toplevel term

args((H :- _), ARGS) :- args1(H, ARGS).
args(H, ARGS) :- args1(H, ARGS).

args1(T, ARGS) :-
    tuple(T) | tuple_to_list(T, L, []), args2(L, ARGS).
args1(_, ARGS) :- otherwise | ARGS := [].

args2([_|XS], ARGS) :- ARGS := XS.

% extract variables from term

vars(T, TAG, VS) :- vars(T, TAG, [], VS).

vars('$VAR'(TAG, I, N), TAG, VS1, VS) :- 
    VS := [{I, N}|VS1].
vars([X|R], TAG, VS1, VS) :-
    vars(X, TAG, VS1, VS2), 
    vars(R, TAG, VS2, VS).
vars(T, TAG, VS1, VS) :-
    tuple(T) | 
    tuple_to_list(T, L, []), 
    vars(L, TAG, VS1, VS).
vars(_, _, VS1, VS) :- 
    otherwise | VS := VS1.

% classify process-definition clauses by 1st argument

classify_arg([], _, TL, LL, AL, OL) :-
    TL := [], LL := [], AL := [], OL := [].
classify_arg([(H :- G | BODY)|R], VTAG, TL, LL, AL, OL) :-
    classify_guard(G, MODE),
    classify_arg_guarded(MODE, (H :- G | BODY), R, VTAG, TL, LL, AL, OL).
classify_arg([T|R], VTAG, TL, LL, AL, OL) :-
    args(T, ARGS),
    classify_arg1(ARGS, T, R, VTAG, TL, LL, AL, OL).

classify_arg1([], T, R, _, TL, LL, AL, OL) :- 
    TL := [], LL := [], AL := [], OL := [T|R].
classify_arg1(['$VAR'(VTAG, _, _)|_], T, R, VTAG, TL, LL, AL, OL) :-
    OL := [T|OL2], 
    classify_arg(R, VTAG, TL, LL, AL, OL2).
classify_arg1([X|_], T, R, VTAG, TL, LL, AL, OL) :-
    tuple(X) | 
    TL := [T|TL2], 
    classify_arg(R, VTAG, TL2, LL, AL, OL).
classify_arg1([X|_], T, R, VTAG, TL, LL, AL, OL) :-
    list(X) | 
    LL := [T|LL2], 
    classify_arg(R, VTAG, TL, LL2, AL, OL).
classify_arg1([_|_], T, R, VTAG, TL, LL, AL, OL) :-
    otherwise | % integer or string
    AL := [T|AL2], 
    classify_arg(R, VTAG, TL, LL, AL2, OL).

classify_arg_guarded(other, CL, R, _, TL, LL, AL, OL) :-
    TL := [], LL := [], AL := [], OL := [CL|R].
classify_arg_guarded(MODE, CL, R, VTAG, TL, LL, AL, OL) :-
    MODE =\= other |
    args(CL, ARGS),
    classify_arg1(ARGS, CL, R, VTAG, TL, LL, AL, OL).

classify_guard(otherwise, R) :- R := other.
classify_guard(idle, R) :- R := other.
classify_guard((G1, G2), R) :-  
    classify_guard(G1, R1),
    classify_guard(R1, G2, R).
classify_guard(_, R) :- otherwise | R := none.

classify_guard(other, _, R) :- R := other.
classify_guard(X, G, R) :- 
    X =\= other | classify_guard(G, R).

% flatten conjunctions into list

flatten_body(X, B) :- flatten_body(X, B, []).

flatten_body(when(X, (Y, Z)), B, TL) :-
    flatten_body((when(X, Y), when(X, Z)), B, TL).
flatten_body((true, Y), B, TL) :- flatten_body(Y, B, TL).
flatten_body((X, true), B, TL) :- flatten_body(X, B, TL).
flatten_body((X, Y), B, TL) :-
    X =\= true, Y =\= true |
    flatten_body(X, B, TL1), flatten_body(Y, TL1, TL).
flatten_body(X, B, TL) :- 
    otherwise | B := [X|TL].

% determine if term is ground

constant_term('$VAR'(VT, _, _), VT, R) :- R := no.
constant_term([X|Y], VT, R) :-
    constant_term(X, VT, R1),
    constant_term(R1, Y, VT, R).
constant_term(T, VT, R) :-
    tuple(T) | 
    tuple_to_list(T, L, []),
    constant_term(L, VT, R).
constant_term(_, _, R) :- otherwise | R := yes.

constant_term(yes, X, VT, R) :- constant_term(X, VT, R).
constant_term(no, _, _, R) :- R := no.

% determine if clause head is "simple" (only contains variables),
% returning reversed list of var-indices or 'no'. Only single variable
% occurrences are allowed.
simple_clause(C, VT, Vars) :-
    otherwise |
    args(C, Args),
    simple_clause2(Args, VT, [], Vars).

simple_clause2([], _, Vars, R) :- R := Vars.
simple_clause2(['$VAR'(VT, I, _)|Args], VT, Vars, R) :-
    simple_clause3(Vars, I, Args, VT, Vars, R).
simple_clause2([_|_], _, _, R) :- otherwise | R := no.

simple_clause3([], I, Args, VT, Vars, R) :-
    simple_clause2(Args, VT, [I|Vars], R).
simple_clause3([I|_], I, _, _, _, R) :- R := no.
simple_clause3([I2|Vs], I, Args, VT, Vars, R) :-
    I2 =\= I | simple_clause3(Vs, I, Args, VT, Vars, R).
