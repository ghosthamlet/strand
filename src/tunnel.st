% tunnel node for distributed operation
%
% should be started with the option "-P N", where N is the target
% machine ID.

-exports(['$start'/0]).

'$start' :-
    '$events'(ES),
    listen(0, INCOMING),
    accept(INCOMING),
    loop(ES).

loop([]) :- '$log'('event stream closed').
loop([E|ES]) :- handle(E), loop(ES).

% internal events
handle(send_read(ID, PID)) :-
    '$send'(PID, read(ID, PID, 0)).
handle(send_value(ID, PID, X)) :-
    '$send'(PID, value(ID, PID, X)).
handle(send_addref(PID, ID)) :-
    '$send'(PID, addref(ID)).

% external events
handle(read(ID, SELF, PID)) :-
    '$get_exposed'(ID, X), 
    send_value(X, PID, ID, SELF).  % suspends on X
handle(value(ID, OWNER, X)) :- 
    '$assign_remote'(ID, OWNER, X).
handle(addref(ID)) :-
    '$add_reference'(ID).
handle(terminate) :- 
    write(1, '0       ', DONE),
    stop(DONE).
handle({PID, MSG}) :-
    '$forward'(1, {PID, MSG}).
handle(E) :- 
    otherwise | '$log'(unkown_event(E)).

send_with(SELF, DEST, MSG) :- 
    data(SELF) | '$send'(DEST, MSG).

send_value(X, PID, ID, SELF) :-
    data(X) |
    '$drop_reference'(ID),
    '$send'(PID, value(ID, SELF, X)).

stop([]) :- halt(0).

accept([]) :-
    '$read_forwarded'(0, MSG),
    '$deliver'(MSG),
    listen(0, INCOMING),
    accept(INCOMING).
