% Strand parser
%
%   parse:parse_module(TOKENS?, VTAG?, FORMS^, ERRS^)
%       Parses period-terminated toplevel expressions from the token stream
%       TOKENS, with VTAG being a unique integer used for tagging variable
%       placeholders (of the form '$VAR'(VTAG, INDEX, NAME)) and writes
%       each toplevel form into the stream FORMS. ERRS is a stream 
%       receiving error messages in the form {LINENUM, FMT, ARGS, CODE}.
%
%   parse:parse_expr(TOKENS?, VTAG?, RTOKENS^, EXP^, ERRS^, ERRS2^)
%       Parses a single expressions, termianted by period and assigns it to
%       EXP. If the expression contains variables, ERRS is the error stream
%       and ERRS2 its tail.

-exports([parse_module/4, parse_expr/6]).

parse_module([], _, O, E) :- O := [], E := [].
parse_module(TOKS, VTAG, O, E) :- 
    otherwise | 
    parse_expr(TOKS, VTAG, RTOKS, X, E, E1), 
    O := [X|O2],
    parse_module(RTOKS, VTAG, O2, E1).

parse_expr(T, VTAG, RT, X, E, E2) :- 
    expr(T, VTAG, [], _, RT1, X, E, E1),
    parse_expr1(RT1, RT, E1, E2).

parse_expr1([punct(_, 0'.)|T], RT, E, E2) :- 
    RT := T, E2 := E.
parse_expr1(T, RT, E, E2) :- 
    otherwise | 
    RT := [], expected(T, period, E, E2).

expected([], N, E, E2) :-
    E := [{0, 'expected ~a at end of file\n', [N], 1}|E2].
expected([{_, L, _}|_], N, E, E2) :-
    E := [{L, 'expected ~a\n', [N], 1}|E2].

expr(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr1(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    clause(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

clause([op(_, ':-')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr1(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 :- X2).
clause(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr1(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr2(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    body(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

body([punct(_, 0'|)|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr1(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 | X2).
body(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr2(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    and(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

and([punct(_, 0',)|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr2(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1, X2).
and(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr3(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr3b(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    seq(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

seq([op(_, '&')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr3(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := '&'(X1, X2).
seq(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr3b(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr4(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    assgn(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

assgn([op(_, ':=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr4(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 := X2).
assgn([id(_, is)|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr4(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 is X2).
assgn(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr4(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr5(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    comp(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

comp([op(_, '<')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 < X2).
comp([op(_, '>')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 > X2).
comp([op(_, '>=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 >= X2).
comp([op(_, '=<')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 =< X2).
comp([op(_, '==')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 == X2).
comp([op(_, '=\\=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 =\= X2).
comp([op(_, '=:=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 =:= X2).
comp([op(_, '\\=:=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 \=:= X2).
comp([op(_, '@>')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 @> X2).
comp([op(_, '@<')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 @< X2).
comp([op(_, '@>=')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 @>= X2).
comp([op(_, '@=<')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 @=< X2).
comp([op(_, '@')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 @ X2).
comp(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr5(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr6(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    qual(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

qual([op(_, ':')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr5(T, VT, ENV, RENV, RT, X2, E, E2), 
    X := (X1 : X2).
qual(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr6(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    add(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

add([op(_, '+')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT2, X2, E, E1),
    X3 := (X1 + X2), 
    add(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
add([op(_, '-')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 - X2), 
    add(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
add([op(_, '/\\')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 /\ X2), 
    add(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
add([op(_, '\\/')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 \/ X2), 
    add(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
add([op(_, '><')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr7(T, VT, ENV, ENV1, RT2, X2, E, E1),     
    X3 := (X1 >< X2), 
    add(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
add(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr7(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    mul(RT1, VT, ENV1, RENV, RT, X1, X, E1, E2).

mul([op(_, '*')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 * X2), 
    mul(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
mul([op(_, '/')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 / X2), 
    mul(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
mul([op(_, '\\\\')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 \\ X2), 
    mul(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
mul([op(_, '<<')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 << X2), 
    mul(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
mul([op(_, '>>')|T], VT, ENV, RENV, RT, X1, X, E, E2) :- 
    expr8(T, VT, ENV, ENV1, RT2, X2, E, E1), 
    X3 := (X1 >> X2), 
    mul(RT2, VT, ENV1, RENV, RT, X3, X, E1, E2).
mul(T, _, ENV, RENV, RT, X1, X, E, E2) :- 
    otherwise | 
    RT := T, X := X1, RENV := ENV, E2 := E.

expr8([op(_, '-'), num(_, N)|T], _, ENV, RENV, RT, X, E, E2) :- 
    RT := T, X is -N, RENV := ENV, E2 := E.
expr8([op(_, '-'), T1|T], VT, ENV, RENV, RT, X, E, E2) :- 
    T1 =\= num(_, _) | 
    expr8([T1|T], VT, ENV, RENV, RT, X1, E, E2), 
    X := -X1.
expr8([op(_, '\\')|T], VT, ENV, RENV, RT, X, E, E2) :- 
    expr8(T, VT, ENV, RENV, RT, X1, E, E2),    
    X := \X1.
expr8(T, VT, ENV, RENV, RT, X, E, E2) :- 
    otherwise | 
    expr10(T, VT, ENV, RENV, RT, X, E, E2).

expr10([punct(_, 0'{), punct(_, 0'})|T], _, ENV, RENV, RT, X, E, E2) :- 
    RT := T, X := {}, RENV := ENV, E2 := E.
expr10([punct(_, 0'{)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    tup(T, VT, ENV, RENV, RT, X, E, E2).
expr10([punct(_, 0'[), punct(_, 0'])|T], _, ENV, RENV, RT, X, E, E2) :- 
    RT := T, X := [], RENV := ENV, E2 := E.
expr10([punct(_, 0'[)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    list(T, VT, ENV, RENV, RT, X, E, E2).
expr10([punct(_, 0'()|T], VT, ENV, RENV, RT, X, E, E2) :- 
    expr(T, VT, ENV, RENV, RT1, X, E, E1), 
    close(RT1, RT, E1, E2).
expr10([num(_, N)|T], _, ENV, RENV, RT, X, E, E2) :- 
    RT := T, X := N, RENV := ENV, E2 := E.
expr10([var(_, NAME)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    mkvar(VT, ENV, RENV, NAME, X), RT := T, E2 := E.
expr10([id(_, ID)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    term(ID, T, VT, ENV, RENV, RT, X, E, E2).
expr10([str(_, S)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    term(S, T, VT, ENV, RENV, RT, X, E, E2).
expr10([lst(_, L)|T], VT, ENV, RENV, RT, X, E, E2) :- 
    term(L, T, VT, ENV, RENV, RT, X, E, E2).
expr10([bytes(_, B)|T], _, ENV, RENV, RT, X, E, E2) :-
    RT := T, X := B, RENV := ENV, E2 := E.
expr10(T, _, _, _, RT, X, E, E2) :-
    otherwise | 
    RT := [], X := '<none>',
    expected(T, 'process definition or declaration', E, E2).

tup(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    tup1(RT1, VT, ENV1, RENV, RT, [X1|TR], TR, X, E1, E2).

tup1([punct(_, 0'})|T], _, ENV, RENV, RT, TUP, TR, X, E, E2) :- 
    RT := T, TR := [], RENV := ENV, E2 := E,
    list_to_tuple(TUP, X).
tup1([punct(_, 0',)|T], VT, ENV, RENV, RT, TUP, TR, X, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    TR := [X1|TR2], 
    tup1(RT1, VT, ENV1, RENV, RT, TUP, TR2, X, E1, E2).
tup1(T, _, _, _, RT, _, _, X, E, E2) :-
    otherwise | 
    RT := [], X := {},
    expected(T, 'comma or closing brace', E, E2).

list(T, VT, ENV, RENV, RT, X, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    X := [X1|LR], 
    list1(RT1, VT, ENV1, RENV, RT, LR, E1, E2).

list1([punct(_, 0'])|T], _, ENV, RENV, RT, LR, E, E2) :- 
    RT := T, LR := [], RENV := ENV, E2 := E.
list1([punct(_, 0'|)|T], VT, ENV, RENV, RT, LR, E, E2) :- 
    expr3(T, VT, ENV, RENV, RT1, LR, E, E1),
    listend(RT1, RT, E1, E2).
list1([punct(_, 0',)|T], VT, ENV, RENV, RT, LR, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1), 
    LR := [X1|LR2], 
    list1(RT1, VT, ENV1, RENV, RT, LR2, E1, E2).
list1(T, _, _, _, RT, LR, E, E2) :-
    otherwise | 
    RT := [], LR := [],
    expected(T, 'comma, vertical bar or closing bracket', E, E2).

listend([punct(_, 0'])|T], RT, E, E2) :- 
    RT := T, E2 := E.
listend(T, RT, E, E2) :- 
    otherwise | 
    RT := [], 
    expected(T, 'closing bracket', E, E2).

close([punct(_, 0'))|T], RT, E, E2) :- 
    RT := T, E2 := E.
close(T, RT, E, E2) :- 
    otherwise | 
    RT := [], 
    expected(T, 'closing parenthesis', E, E2).

term(H, [punct(_, 0'()|T], VT, ENV, RENV, RT, X, E, E2) :- 
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1),
    term1(RT1, VT, ENV1, RENV, RT, [H, X1|TR], TR, X, E1, E2).
term(H, T, _, ENV, RENV, RT, X, E, E2) :- 
    otherwise | 
    RT := T, X := H, RENV := ENV, E2 := E.

term1([punct(_, 0'))|T], _, ENV, RENV, RT, TUP, TR, X, E, E2) :-
    TR := [], 
    list_to_tuple(TUP, X), 
    RT := T, RENV := ENV, E2 := E.
term1([punct(_, 0',)|T], VT, ENV, RENV, RT, TUP, TR, X, E, E2) :-
    expr3(T, VT, ENV, ENV1, RT1, X1, E, E1),
    TR := [X1|TR2], 
    term1(RT1, VT, ENV1, RENV, RT, TUP, TR2, X, E1, E2).
term1(T, _, ENV, RENV, RT, TUP, TR, X, E, E2) :-
    otherwise |
    TR := [], RT := T, RENV := ENV,
    list_to_tuple(TUP, X), 
    expected(T, 'closing parenthesis in term', E, E2).

mkvar(VT, ENV, RENV, NAME, VAR) :- 
    mkvar1(ENV, VT, NAME, ENV, 0, RENV, VAR).

mkvar1([], VT, NAME, ENV, I, RENV, VAR) :-
    RENV := [{NAME, I}|ENV],
    VAR := '$VAR'(VT, I, NAME).
mkvar1([{_, VI}|_], VT, '_', ENV, _, RENV, VAR) :-
    I is VI + 1,
    RENV := [{'_', I}|ENV],
    VAR := '$VAR'(VT, I, '_').
mkvar1([{NAME, VI}|_], VT, NAME, ENV, _, RENV, VAR) :-
    NAME =\= '_' |
    RENV := ENV,
    VAR := '$VAR'(VT, VI, NAME).
mkvar1([_|ENV1], VT, NAME, ENV, I, RENV, VAR) :- 
    otherwise |
    I2 is I + 1, 
    mkvar1(ENV1, VT, NAME, ENV, I2, RENV, VAR).
