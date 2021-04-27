% communicate over file descriptors with subprocesses
%
% run with -P 32

main :-
    bsys:connect([yin(33, [strandvm, '-P', '33', bstub], Ok1), 
        yang(34, [strandvm, '-P', '34', bstub], Ok2)]),
    deref(Ok1/Ok2, Ok),
    when(Ok, ping(X)@yin),
    writeln(X),
    when(Ok, ping(Y)@yang),
    writeln(Y).

ping(X) :-
    current_node(Self),
    '$log'(ping),
    X := pong(Self).
