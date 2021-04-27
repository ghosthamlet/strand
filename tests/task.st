% task tests

-exports([main/0, foo/1, spin/2, bomb/0, nop/0]).

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
    succeed(R1), r(success, R1, {99, success}, S0, S1),
    suspend_resume(S1, R2), 
        r(suspend_resume, R2, {ok, [suspend, suspend|success]}, 
            S1, S2),
    failed(S2, R3), r(fail, R3, fail(bomb), S2, S3),    
    stopped(S3, R4), r(stop, R4, stop, S3, S4),
    failed_spawn(S4, R5), r(failed_spawn, R5, fail('module not found'), S4, S5),
    failed_spawn2(S5, R6), r(failed_spawn2, R6, fail('module-export not found'), S5, S6),
    run(task, nop, R7, _), r(atomic, R7, success, S6, S7),
    succeed2(R8), r(success_local, R8, {99, success}, S7, S8),
    run(nop, R9, _), r(atomic_local, R9, success, S8, S9),
    report(S9).

% spawn normally
succeed(R) :- run(task, foo(X), S, _), R := {X, S}.
foo(X) :- X := 99.
succeed2(R) :- run(foo(X), S, _), R := {X, S}.
nop.

% suspend/resume/suspend/resume
suspend_resume(X, R) :-
    data(X) |
    run(task, spin(5, R1), S, [suspend|C]),
    R := {R1, S},
    resume(S, C).

resume([suspend|S], C) :- 
    C := [resume|C2], suspend(S, C2).
suspend(S, C) :- 
    C := [suspend|C2], resume2(S, C2).

resume2([suspend|_], C) :-
    C := [resume|_].

spin(0, R) :- R := ok.
spin(N, R) :- N > 0 | N1 is N - 1, spin(N1, R).

% fail with error
failed(X, R) :-
    data(X) |
    run(task, bomb, R, _).

bomb :- error(bomb).

% stop
stopped(X, R) :-
    data(X) |
    run(task, spin(10, _), R, C),
    C := stop.

% failed module/process lookup
failed_spawn(X, R) :-
    data(X) | run(unknown, xxx, R, _).

failed_spawn2(X, R) :-
    data(X) | run(task, xxx, R, _).
