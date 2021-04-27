% compile file over 3 nodes

-exports([main/0]).
-machine(ring).

main :-
    lex:lex_file('src/compile.st', TOKS, EL)@bwd,
    compile:init_state('test.in', 'test.out', S1, VTAG, EC),
    parse:parse_module(TOKS, VTAG, FORMS, EP)@fwd,
    compile:compile_forms(FORMS, S1, DONE),
    done({EL, EP, EC, DONE}).

done({[], [], [], []}) :- 
    shell('tests/chkresult', S), writeln(S).
