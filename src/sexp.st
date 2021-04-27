% S-expression parsing.
%
%   sexp:read(S?, X^, S2^)
%       Parse s-expression from the character stream S and assign it to X.
%       S2 contains the rest of the input stream after X has been read.
%
%   Mapping of s-expressions to Strand terms:
%
%       symbol:         string
%       quoted string:  character list
%       list:           list
%       integer:        integer
%
% On end  of input, read/3 returns the string "eof" and closes the output stream.

-exports([read/3]).

read(S, X, S2) :- skipws(S, S1), read2(S1, X, S2).

read2([], X, S) :- X := eof, S := [].
read2([0'(|S], X, S2) :- skipws(S, S1), read_list(S1, X, S2).
read2([0'"|S], X, S2) :- read_qstring(S, X, S2).
read2(S, X, S2) :- otherwise | read_token(S, T, T, num, X, S2).

read_list([0')|S], X, S2) :- X := [], S2 := S.
read_list(S, X, S2) :-
    otherwise | 
    read(S, Y, S1), 
    X := [Y|X2],
    skipws(S1, S3),
    read_list(S3, X2, S2).

skipws([32|S], S2) :- skipws(S, S2).
skipws([9|S], S2) :- skipws(S, S2).
skipws([10|S], S2) :- skipws(S, S2).
skipws([13|S], S2) :- skipws(S, S2).
skipws(S, S2) :- otherwise | S2 := S.

read_qstring([0'"|S], X, S2) :- X := [], S2 := S.
read_qstring([0'\\, C|S], X, S2) :- 
    escape(C, C2), X := [C2|X2], read_qstring(S, X2, S2).
read_qstring([C|S], X, S2) :- 
    otherwise | X := [C|X2], read_qstring(S, X2, S2).

escape(0'n, C) :- C := 10.
escape(0'r, C) :- C := 13.
escape(0't, C) :- C := 9.
escape(C1, C) :- otherwise | C := C1.

read_token([], T1, T2, CL, X, S) :-
    T2 := [], S := [], token(CL, T1, X).
read_token([C|S], T1, T2, CL, X, S2) :-
    classify(C, CL2),
    read_token2(CL2, C, S, T1, T2, CL, X, S2).

classify(C, TC) :- C =< 32 | TC := t.
classify(0'(, TC) :- TC := t.
classify(0'), TC) :- TC := t.
classify(0'", TC) :- TC := t.
classify(C, TC) :- C >= 0'0, C =< 0'9 | TC := num.
classify(_, TC) :- otherwise | TC := tok.

read_token2(t, C, S, T1, T2, CL, X, S2) :-
    S2 := [C|S], 
    T2 := [],
    token(CL, T1, X).
read_token2(num, C, S, T1, T2, num, X, S2) :-
    T2 := [C|T],
    read_token(S, T1, T, num, X, S2).
read_token2(CL, C, S, T1, T2, _, X, S2) :-
    T2 := [C|T],
    read_token(S, T1, T, CL, X, S2).

token(num, T, X) :- list_to_integer(T, X).
token(tok, T, X) :- list_to_string(T, X).
