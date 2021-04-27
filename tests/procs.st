% process tests

-exports([main/0]).

ok({OK, NOTOK}, S) :- 
    OK2 is OK + 1, S := {OK2, NOTOK}.
notok({OK, NOTOK}, S) :- 
    NOTOK2 is NOTOK + 1, S := {OK, NOTOK2}.

r(_, E, E, S, S2) :- ok(S, S2).
r(T, R, E, S, S2) :- 
    R =\= E | 
    notok(S, S2), writeln(failed(T, R, E)).

report({_, 0}) :-
    writeln('all tests succeeded.').
report({OK, NOTOK}) :-
    writeln(tests_succeeded(OK)),
    writeln(tests_failed(NOTOK)).

main :-
    S0 := {0, 0},
    proc:execute('/bin/echo', [], PID, ST1), r(minimal, ST1, 0, S0, S1),
        isint(PID, R0), r(pid, R0, yes, S1, S1x),
    proc:execute(true, [], _, ST2), r(searchpath, ST2, 0, S1x, S2),
    proc:execute(false, [], _, ST3), r(fail, ST3, 1, S2, S3),
    proc:capture([expr, "3", '+', "4"], ST4, R1),
        r(capture, {ST4, R1}, {0, "7"}, S3, S4),
    proc:execute(ls, [close(in), close(out)], _, ST5), r(close, ST5, 0, S4, S5),
    filter(ST6, R2), r(filter, {ST6, R2}, {0, "abc"}, S5, S6),
    report(S6).

filter(S, R) :-
    proc:execute([tr, '-d', x], [pipe(in, IN), pipe(out, OUT)], _, S),
    write_chars(IN, "axbxc", OK),
    done(OK, IN),
    io:read_char_stream(OUT, R).

done([], F) :- close_file(F).

isint(X, R) :- integer(X) | R := yes.
isint(_, R) :- otherwise | R := no.
