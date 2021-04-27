% subprocess invocation
%
% proc:execute(STRLIST?, OPTIONS?, PID^, STATUS^)
%   Execute command in STRLIST, which may be a string or a list
%   of strings or character lists, with I/O channels connected to the 
%   child process. 
%   OPTIONS is a list of one ore more forms of the following kind:
%
%     use(CH?, FILE?)     redirect FILE to channel
%     open(CH?, STR?)     open file named STR and redirect from/to 
%                         channel
%     close(CH?)          close channel
%     pipe(CH?, FILE^)    open bi-directional pipe for channel
%
%     CH may be one of the strings in, out or err.
%
% proc:capture(STRLIST?, STATUS^, RESULT^)
%   Execute the command in STRLIST (as in execute/3) with
%   the output of the command captured in a character list and 
%   assigned to RESULT.

-exports([execute/4, capture/3]).

execute(CMD, O, PID, S) :-
    string(CMD) | execute([CMD], O, PID, S).
execute(CMD, O, PID, S) :-
    otherwise |
    execute1(O, CMD, S, no, no, no, [], PID).

execute1([], CMD, ST, no, OUT, ERR, CL, PID) :-
    execute1([], CMD, ST, 0, OUT, ERR, CL, PID).
execute1([], CMD, ST, IN, no, ERR, CL, PID) :-
    execute1([], CMD, ST, IN, 1, ERR, CL, PID).
execute1([], CMD, ST, IN, OUT, no, CL, PID) :-
    execute1([], CMD, ST, IN, OUT, 2, CL, PID).
execute1([], CMD, ST, IN, OUT, ERR, CL, PID) :-
    IN =\= no, OUT =\= no, ERR =\= no |
    '$execute'(CMD, ST, IN, OUT, ERR, CL, PID).
execute1([use(in, FD)|O], CMD, ST, no, OUT, ERR, CL, PID) :-
    execute1(O, CMD, ST, FD, OUT, ERR, CL, PID).
execute1([use(out, FD)|O], CMD, ST, IN, no, ERR, CL, PID) :-
    execute1(O, CMD, ST, IN, FD, ERR, CL, PID).
execute1([use(err, FD)|O], CMD, ST, IN, OUT, no, CL, PID) :-
    execute1(O, CMD, ST, IN, OUT, FD, CL, PID).
execute1([open(in, FN)|O], CMD, ST, no, OUT, ERR, CL, PID) :-
    open_file(FN, r, IN),
    close(PID, IN),
    execute1(O, CMD, ST, IN, OUT, ERR, CL, PID).
execute1([open(out, FN)|O], CMD, ST, IN, no, ERR, CL, PID) :-
    open_file(FN, w, OUT),
    close(PID, OUT),
    execute1(O, CMD, ST, IN, OUT, ERR, CL, PID).
execute1([open(err, FN)|O], CMD, ST, IN, OUT, no, CL, PID) :-
    open_file(FN, w, ERR),
    close(PID, ERR),
    execute1(O, CMD, ST, IN, OUT, ERR, CL, PID).
execute1([close(in)|O], CMD, ST, no, OUT, ERR, CL, PID) :-
    open_pipe(IN, FD),
    close(PID, IN),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD|CL], PID).
execute1([close(out)|O], CMD, ST, IN, no, ERR, CL, PID) :-
    open_pipe(FD, OUT),
    close(PID, OUT),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD|CL], PID).
execute1([close(err)|O], CMD, ST, IN, OUT, no, CL, PID) :-
    open_pipe(FD, ERR),
    close(PID, ERR),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD|CL], PID).
execute1([pipe(in, FD)|O], CMD, ST, no, OUT, ERR, CL, PID) :-
    open_pipe(IN, FD1),
    delay(PID, IN, FD1, FD),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD1|CL], PID).
execute1([pipe(out, FD)|O], CMD, ST, IN, no, ERR, CL, PID) :-
    open_pipe(FD1, OUT),
    delay(PID, OUT, FD1, FD),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD1|CL], PID).
execute1([pipe(err, FD)|O], CMD, ST, IN, OUT, no, CL, PID) :-
    open_pipe(FD1, ERR),
    delay(PID, ERR, FD1, FD),
    execute1(O, CMD, ST, IN, OUT, ERR, [FD1|CL], PID).
execute1(O, CMD, _, _, _, _, _, _, _) :-
    otherwise |
    error(invalid_execute_options(CMD, O)).

% assign when subprocess is started in case of blocking I/O on D:
delay(X, F, S, D) :- data(X) | close_file(F, Ok), delay(Ok, S, D).
delay([], S, D) :- D := S.

capture(CMD, S, R) :-
    proc:execute(CMD, [pipe(out, O)], _, S),
    io:read_char_stream(O, R2),
    list:trim_right(R2, 10, R),
    close(R2, O).

% close parent FD if reply stream is fully ground
close(X, F) :- deref(X, OK), close2(OK, F).
close2([], F) :- close_file(F).
