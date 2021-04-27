-exports([main/0]).

main :-
    command_line(Args),
    run_module(Args).

run_module([Mod]) :-
    get_module(Mod, Module),
    run(Module, '$META'(Info)),
    get_machine_type(Info, Type),
    sys:execute(Module, Type, Status),
    wait(Status).

wait(success) :- halt(0).
wait(Status) :- otherwise | error(Status).

get_machine_type([], Type) :- Type := ring.
get_machine_type([machine(ring)|_], Type) :- Type := ring.
get_machine_type([machine(torus)|_], Type) :- Type := torus.
get_machine_type([machine(X)|_], _) :- 
    otherwise |
    error(unknown_machine_type(X)).
get_machine_type([_|Info], Type) :- 
    otherwise | get_machine_type(Info, Type).
