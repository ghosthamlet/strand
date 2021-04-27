% Reading Strand terms
%
%   strand:read_terms(INPUT?, TERMS^, ERRORS^)
%       Read terms from INPUT into stream TERMS. Lexical or
%       syntactical errors result in error messages written to
%       the stream ERRORS, where each message has the following
%       form: {LINENUM, FORMAT, ARGS, EXITCODE}.
%       INPUT may be a filename, a file descriptor or a character
%       stream.
%       Variables are read as tuples of the form 
%       '$VAR'(MARK, INDEX, NAME)
%       where MARK is some unique integer, INDEX is the variable
%       index in the term and NAME is the variable name.
%
%   strand:write_terms(TERMS?, OUTPUT?)
%   strand:write_terms(TERMS?, OUTPUT?, OK^)
%       Write terms in list TERMS to file OUTPUT in a manner readable by
%       read_terms/3. When done, assign the empty list to OK.

-exports([read_terms/3, write_terms/2, write_terms/3]).

read_terms(FILE, TS, ES) :-
    integer(FILE) |
    io:read_char_stream(FILE, IN),
    read_terms(IN, TS, ES).
read_terms(FNAME, TS, ES) :-
    string(FNAME) |
    open_file(FNAME, r, IN),
    read_terms(IN, TS, ES),
    close_on_end(TS, IN).
read_terms(IN, TS, ES) :-
    rnd:pseudo_random_integer(VT1, _),
    VT is abs(VT1) \\ 100000,
    lex:lex(IN, 1, TOKS, ESL),
    parse(TOKS, VT, TS, ESP),
    merger([merge(ESL), merge(ESP)], ES).

parse([], _, TS, ESP) :- TS := [], ESP := [].
parse(TOKS, VT, TS, ESP) :-
    otherwise |
    parse:parse_expr(TOKS, VT, TOKS2, T, ESP, ESP2),
    TS := [T|TS2],
    parse(TOKS2, VT, TS2, ESP2).

close_on_end([], IN) :- close_file(IN).
close_on_end([_|R], IN) :- close_on_end(R, IN).

write_terms(Terms, Out) :- write_terms(Terms, Out, _).

write_terms([], _, OK) :- OK := [].
write_terms([T|Terms], Out, OK) :-
    fmt:format(Out, "~q.\n", [T], W),
    write_terms(W, Terms, Out, OK).

write_terms([], Terms, Out, OK) :- write_terms(Terms, Out, OK).
