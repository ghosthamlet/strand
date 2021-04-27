% formatted output
%
%     fmt:format(STRING?, ARGS?)
%       Writes the values in the list ARGS in a manner described by
%       the format string STRING. STRING may be a string or a list 
%       of character codes and may contain special characters 
%       describing how to output the next item in ARGS.
% 
%         ~~  Output the "~" (tilde) character.
% 
%         ~a  Output the unquoted characters of the next argument
%             which must be a string.
%
%         ~s  Output the string, byte block or character list given in the next 
%               argument.
% 
%         ~d  Output the next argument, which must be a number, in
%             decimal notation.
% 
%         ~x  Output the next argument, which must be a number, in
%             hexadecimal notation.
% 
%         ~w  Output the next argument term in operator syntax.
% 
%         ~q  Output the next argument term in operator syntax and with
%             strings quoted, if necessary.
% 
%         ~c  Output the next argument which must be an integer as
%             a single character.
% 
%         ~n  Output a newline character.
%
%         ~?  Take a format-string and argument-list, format recursively.
% 
%     fmt:format(STRING?, ARGS?, DONE^)
%       Write the formatted output to FILE and assign [] to DONE
%       when finished.
% 
%     fmt:format(FILE?, STRING?, ARGS?)
%     fmt:format(FILE?, STRING?, ARGS?, DONE^)
%       Write the formatted output to FILE. Assign the empty list to
%       DONE when the output is completed.
%
%     fmt:format_chars(STRING?, ARGS?, OUT^)
%     fmt:format_chars(STRING?, ARGS?, OUT^, TAIL?)
%       Format to list of character codes and assign to OUT,
%       optionally with a list tail, which defaults to the empty_list.
%       STRING may be a string or a list of characters.

-exports([format/2, format/3, format/4]).
-exports([format_chars/3, format_chars/4]).

format(STR, ARGS) :-
    format0(1, STR, ARGS, _, _).

format(FD, STR, ARGS) :-
    integer(FD) |   
    format0(FD, STR, ARGS, _, _).
format(STR, ARGS, DONE) :-
    otherwise |
    format0(1, STR, ARGS, _, DONE).

format(FD, STR, ARGS, DONE) :-
    format0(FD, STR, ARGS, _, DONE).

format_chars(STR, ARGS, OUTS, TAIL) :-
    to_list(STR, FMT),
    outputs(OUT, OUTS, TAIL),
    format1(FMT, ARGS, OUT).

format_chars(STR, ARGS, OUTS) :-
    format_chars(STR, ARGS, OUTS, []).

format0(FD, STR, ARGS, OUT, DONE) :-
    to_list(STR, FMT),
    output(OUT, FD, DONE),
    format1(FMT, ARGS, OUT).

to_list(X, L) :- string(X) | string_to_list(X, L, []).
to_list(X, L) :- list(X) | L := X.

format1([], [], O) :- O := [].
format1([], ARGS, _) :- 
    ARGS =\= [] |
    error(format_too_many_arguments(ARGS)).
format1([0'~, C|R], ARGS, O) :-
    format1(C, R, ARGS, O).
format1([C|R], ARGS, O) :-
    otherwise | 
    O := [C|O2],
    format1(R, ARGS, O2).

format1(0'a, R, [X|ARGS], O) :-
    string(X) |
    O := [X|O2], format1(R, ARGS, O2).
format1(0'd, R, [X|ARGS], O) :-
    integer(X) |
    O := [{X}|O2], format1(R, ARGS, O2).
format1(0'x, R, [X|ARGS], O) :-
    integer(X) |
    integer_to_list(X, 16, L),
    O := [L|O2], format1(R, ARGS, O2).
format1(0'q, R, [X|ARGS], O) :-
    expr(X, 0, q, O, O2),
    format1(R, ARGS, O2).
format1(0'w, R, [X|ARGS], O) :-
    expr(X, 0, w, O, O2),
    format1(R, ARGS, O2).
format1(0'c, R, [X|ARGS], O) :-
    integer(X) |
    O := [X|O2], format1(R, ARGS, O2).
format1(0's, R, [X|ARGS], O) :-
    bytes(X) |
    bytes_to_list(X, L, []),
    out_list(L, O, O2),
    format1(R, ARGS, O2).
format1(0's, R, [X|ARGS], O) :-
    otherwise |
    out_list(X, O, O2),
    format1(R, ARGS, O2).
format1(0'n, R, ARGS, O) :-
    O := [10|O2], format1(R, ARGS, O2).
format1(0'?, R, [F, AS|ARGS], O) :-
    string(F) |
    string_to_list(F, FL, R),
    list:append(AS, ARGS, ARGS2),
    format1(FL, ARGS2, O).
format1(0'?, R, [F, AS|ARGS], O) :-
    list(F) |
    list:append(F, R, R2),
    list:append(AS, ARGS, ARGS2),
    format1(R2, ARGS2, O).
format1(0'~, R, ARGS, O) :-
    O := [0'~|O2], format1(R, ARGS, O2).
format1(C, _, ARGS, _) :-
    otherwise |
    error(format_bad_format(C, ARGS)).

out_list([], O, O2) :- O := O2.
out_list(X, O, O2) :- otherwise | O := [X|O2].

output([], _, DONE) :- DONE := [].
output([{X}|R], FD, DONE) :-
    write(FD, X, DONE1),
    output1(DONE1, R, FD, DONE).
output([X|R], FD, DONE) :-
    integer(X) |
    write_chars(FD, [X], DONE1),
    output1(DONE1, R, FD, DONE).
output([X|R], FD, DONE) :-
    list(X) |
    write_chars(FD, X, DONE1),
    output1(DONE1, R, FD, DONE).
output([X|R], FD, DONE) :-
    otherwise | 
    write(FD, X, DONE1), 
    output1(DONE1, R, FD, DONE).

output1([], R, FD, DONE) :- output(R, FD, DONE).

outputs([], OUTS, TAIL) :- OUTS := TAIL.
outputs([{X}|R], OUTS, TAIL) :-
    integer(X) | 
    integer_to_list(X, 10, OUTS, TAIL2), 
    outputs(R, TAIL2, TAIL).
outputs([X|R], OUTS, TAIL) :-
    integer(X) |
    OUTS := [X|TAIL2],
    outputs(R, TAIL2, TAIL).
outputs([X|R], OUTS, TAIL) :-
    list(X) |
    list:append(X, TAIL2, OUTS),
    outputs(R, TAIL2, TAIL).
outputs([X|R], OUTS, TAIL) :-
    string(X) |
    string_to_list(X, OUTS, TAIL2),
    outputs(R, TAIL2, TAIL).
outputs([X|R], OUTS, TAIL) :-
    bytes(X) |
    bytes_to_list(X, OUTS, TAIL2),
    outputs(R, TAIL2, TAIL).

append([], TAIL, L) :- L := TAIL.
append([X|R], TAIL, L) :-
    L := [X|TAIL2], 
    append(R, TAIL, TAIL2).

expr('$VAR'(VT, N, Name), _, _, O, O2) :-
    integer(VT), integer(N), string(Name) |
    O := [Name|O2].
expr(X, P, M, O, O2) :-
    tuple(X), X =\= '$VAR'(_, _, _) |
    tuple_to_list(X, T, []),
    expr0(T, P, M, O, O2).
expr(X, _, M, O, O2) :-
    list(X) | 
    O := [0'[|O3],
    expr_list(X, M, O3, O4),
    O4 := [0']|O2].
expr(X, _, _, O, O2) :-
    integer(X) | O := [{X}|O2].
expr(X, _, w, O, O2) :-
    string(X) | O := [X|O2].
expr('', _, q, O, O2) :- 
    O := ['\'\''|O2].
expr(X, _, q, O, O2) :-
    string(X), X =\= '' |
    string_to_list(X, L, []), 
    qstring(L, X, O, O2).
expr(X, _, _, O, O2) :-
    otherwise | O := [X|O2].

expr0([H|A], P, M, O, O2) :-
    string(H), A =\= [] |
    length(A, N),
    op(H/N, PP, ASS),
    expr_op(H, A, P, PP, ASS, M, O, O2).
expr0(T, _, M, O, O2) :-
    otherwise | expr_tuple(T, M, O, O2).

expr_op(OP, A, _, none, _, M, O, O2) :-
    expr_tuple([OP|A], M, O, O2).
expr_op(OP, [X], P, PP, fy, M, O, O2) :-
    PP >= P |
    O := [OP|O3], 
    expr(X, PP, M, O3, O2).
expr_op(OP, [X, Y], P, PP, xfx, M, O, O2) :- 
    PP >= P |
    P2 is PP + 1,
    expr(X, P2, M, O, O4),
    O4 := [32, OP, 32|O5],
    expr(Y, P2, M, O5, O2).
expr_op(OP, [X, Y], P, PP, xfy, M, O, O2) :- 
    PP >= P |
    P2 is PP + 1,
    expr(X, P2, M, O, O3), 
    O3 := [32, OP, 32|O4], 
    expr(Y, PP, M, O4, O2).
expr_op(OP, [X, Y], P, PP, yfx, M, O, O2) :- 
    PP >= P |
    P2 is PP + 1,
    expr(X, PP, M, O, O4),
    O4 := [32, OP, 32|O5],
    expr(Y, P2, M, O5, O2).
expr_op(OP, ARGS, _, PP, ASS, M, O, O2) :- 
    otherwise |
    O := [0'(|O3],
    expr_op(OP, ARGS, PP, PP, ASS, M, O3, O4),
    O4 := [0')|O2].

expr_tuple([H|A], M, O, O2) :-
    string(H), A =\= [] | 
    O := [H, 0'(|O3],
    expr_list(A, M, O3, O4),
    O4 := [0')|O2].
expr_tuple(T, M, O, O2) :-
    otherwise |
    O := [0'{|O3],
    expr_list(T, M, O3, O4),
    O4 := [0'}|O2].

expr_list([X], M, O, O2) :-
    expr(X, 2, M, O, O2).
expr_list([X|R], M, O, O2) :-
    R =\= [], list(R) |
    expr(X, 2, M, O, O3),
    O3 := [0',, 32|O4],
    expr_list(R, M, O4, O2).
expr_list([], _, O, O2) :- O := O2.
expr_list(X, M, O, O2) :-
    otherwise |
    O := [0'||O3],
    expr(X, 2, M, O3, O2).

op((':-')/2, P, A) :- P := 0, A := xfx.
op('|'/2, P, A) :- P := 1, A := xfx.
op(','/2, P, A) :- P := 2, A := xfy.
op('&'/2, P, A) :- P := 3, A := xfy.
op(':='/2, P, A) :- P := 4, A := xfx.
op(is/2, P, A) :- P := 4, A := xfx.
op('<'/2, P, A) :- P := 5, A := xfx.
op('>'/2, P, A) :- P := 5, A := xfx.
op('>='/2, P, A) :- P := 5, A := xfx.
op('=<'/2, P, A) :- P := 5, A := xfx.
op('=='/2, P, A) :- P := 5, A := xfx.
op('=\\='/2, P, A) :- P := 5, A := xfx.
op('@>'/2, P, A) :- P := 5, A := xfx.
op('@<'/2, P, A) :- P := 5, A := xfx.
op('@>='/2, P, A) :- P := 5, A := xfx.
op('@=<'/2, P, A) :- P := 5, A := xfx.
op('@'/2, P, A) :- P := 5, A := xfx.
op(':'/2, P, A) :- P := 6, A := xfx.
op('+'/2, P, A) :- P := 7, A := yfx.
op('-'/2, P, A) :- P := 7, A := yfx.
op('/\\'/2, P, A) :- P := 7, A := yfx.
op('\\/'/2, P, A) :- P := 7, A := yfx.
op('><'/2, P, A) :- P := 7, A := yfx.
op('*'/2, P, A) :- P := 8, A := yfx.
op('/'/2, P, A) :- P := 8, A := yfx.
op('\\\\'/2, P, A) :- P := 8, A := yfx.
op('-'/1, P, A) :- P := 9, A := fy.
op('\\'/1, P, A) :- P := 9, A := fy.
op(_, P, A) :- otherwise | P := none, A := none.

qstring([0'_|R], S, O, O2) :-
    qstring2([0'_|R], yes, S, O, O2).
qstring([C|R], S, O, O2) :-
    C >= 0'0, C =< 0'9 |
    qstring2([C|R], yes, S, O, O2).
qstring(X, S, O, O2) :-
    otherwise |
    qstring1(X, Q),
    qstring2(X, Q, S, O, O2).

qstring1([], Q) :- Q := no.
qstring1([0'_|R], Q) :- qstring1(R, Q).
qstring1([C|R], Q) :- 
    C >= 0'a, C =< 0'z | qstring1(R, Q).
qstring1([C|R], Q) :- 
    C >= 0'A, C =< 0'Z | qstring1(R, Q).
qstring1([C|R], Q) :- 
    C >= 0'0, C =< 0'9 | qstring1(R, Q).
qstring1(_, Q) :-
    otherwise | Q := yes.

qstring2(L, yes, _, O, O2) :-
    O := [0''|O3],
    qstring3(L, O3, O2).
qstring2(_, no, S, O, O2) :- O := [S|O2].

qstring3([], O, O2) :- O := [0''|O2].
qstring3([0''|R], O, O2) :- 
    O := ['\\\''|O3], 
    qstring3(R, O3, O2).
qstring3([10|R], O, O2) :- 
    O := ['\\n'|O3], 
    qstring3(R, O3, O2).
qstring3([13|R], O, O2) :- 
    O := ['\\r'|O3], 
    qstring3(R, O3, O2).
qstring3([9|R], O, O2) :- 
    O := ['\\t'|O3], 
    qstring3(R, O3, O2).
qstring3([C|R], O, O2) :- 
    otherwise |
    O := [C|O3],
    qstring3(R, O3, O2).
