% terminal node for "vm"

-exports([main/0, quit/0, info/1, map/0, ping/3, topology/1, stat/0]).

main :- 
    prompt([], OK),
    loop(OK).

loop([]) :-
    strand:read_terms(0, TERMS, ERRORS),
    handle_errors(ERRORS),
    process_input(TERMS).

handle_errors([]).
handle_errors([ERR|S]) :-
    fmt:format("Error: ~q\n", [ERR]),
    handle_errors(S).

process_input([T|S]) :- command(T, S).

process_input([], S) :- process_input(S).

command(M:T@MAC, In) :-
    sys:mnode(MAC, A),
    call(M, T)@A,
    continue(success, In).
command(X, In) :-
    run(vmterm, X, Status, _),
    continue(Status, In).

continue(Status, In) :-
    Status == success |
    prompt(Status, OK),
    process_input(OK, In).
continue(Status, In) :-
    Status =\= success |
    fmt:format("[~q]\n", [Status], OK),
    prompt(OK, OK2),
    process_input(OK2, In).

prompt(Go, OK) :- data(Go) | write(1, '>> ', OK).

call(M, T) :- run(M, T).

quit :- halt(0).

info(Mac) :-
    sys:mnode(Mac, A),
    '$send'(A, get_info(R)),
    writeln(R).

ping(Mac, Node, R) :-
    sys:ping(Mac, Node, R),
    writeln(R).

map :-
    sys:map(MAP),
    writeln(MAP).

topology(Type) :-
    sys:topology(Type, Top),
    writeln(Top).

% topology must have been built before
stat :-
    sys:nodes(All),
    get_stats(All, Stats),
    dump_stats([], Stats).

get_stats([], S) :- S := [].
get_stats([Addr|All], S) :-
    sys:statistics(St)@Addr,
    S := [{Addr, St}|S2],
    get_stats(All, S2).

dump_stats(_, []).
dump_stats([], [{Addr, St}|Stats]) :-
    fmt:format("~d: ~q\n", [Addr, St], Ok),
    dump_stats(Ok, Stats).
