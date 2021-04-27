% strand compiler - toplevel
%
% expects arguments in the following form:
%
%   strandvm <runtime-options> ... -- INFILE OUTFILE

-exports([main/0, compile_file/2]).

main :-
    command_line(ARGS),
    compile(ARGS).

compile([FROM, TO]) :-
    compile_file(FROM, TO).
compile(_) :-
    otherwise |     
    fmt:format(2, 'usage: strandvm ... -- SOURCE OUTFILE\n', [], OK),
    done(OK, 1).

done([], ST) :- halt(ST).

compile_file(INAME, ONAME) :-
    lex:lex_file(INAME, TOKS, EL),
    compile:init_state(INAME, ONAME, S1, VTAG, EC),
    parse:parse_module(TOKS, VTAG, FORMS, EP),
    merger([merge(EL), merge(EP), merge(EC)], E),
    compile:compile_forms(FORMS, S1, DONE),
    report_errors(E, DONE, INAME, ST),
    halt(ST).

report_errors(ES, DONE, INAME, ST) :- 
    report_errors(ES, DONE, INAME, 0, ST).

report_errors([], [], _, ST, DONE) :- DONE := ST.
report_errors([E|S], [], INAME, CODE1, DONE) :-
    report_error(E, INAME, CODE2, OK),
    CODE is CODE1 \/ CODE2,
    report_errors(S, OK, INAME, CODE, DONE).

report_error({0, FMT, ARGS, CODE}, INAME, CODE2, OK) :-
    fmt:format(2, '~s: ', [INAME], OK1),
    CODE2 := CODE,
    report_error1(OK1, FMT, ARGS, OK).
report_error({L, FMT, ARGS, CODE}, INAME, CODE2, OK) :-
    L =\= 0 |
    CODE2 := CODE,
    fmt:format(2, '~s:~d: ', [INAME, L], OK1),
    report_error1(OK1, FMT, ARGS, OK).

report_error1([], FMT, ARGS, OK) :-
    fmt:format(2, FMT, ARGS, OK).
