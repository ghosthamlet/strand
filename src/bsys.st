% runtime system for file-oriented "buddy" communication
%
% Constraints:
%
% - must be explicitly started using connect/1.
% - no "@all" addressing.
% - addresses are mapped to file-descriptors.

-exports([connect/1, accept/2]).

connect(S) :- 
    '$events'(ES),
    open_port(DB, DBS),
    loop(ES, DB),
    db(DBS, {}),
    connect(S, DB).

accept(I, O) :-
    '$events'(ES),
    open_port(DB, DBS),
    loop(ES, DB),
    db(DBS, {}),
    '$register_peer'(other, 32),
    send(DB, add(32, O, _)),
    receive(I).

connect([], _).
connect([{Peer, Port, Cmd, Ok}|S], DB) :- 
    proc:execute(Cmd, [pipe(in, I), pipe(out, O)], PID, _),
    '$register_peer'(Peer, Port),
    send(DB, add(Port, I, RegOk)),
    start_receive(PID/RegOk, O, Ok),
    connect(S, DB).

start_receive(X, I, Ok) :-
    deref(X, Ok), when(Ok, receive(I)).

receive(File) :-
    listen(File, Input),
    receive(Input, File).

receive([], File) :-
    read_bytes(File, 2, Len),
    bytes_to_list(Len, L, []),
    receive2(L, File).

receive2([], File) :-
    % EOF
    close_file(File).
receive2([H, L], File) :-
    Len is (H << 8) \/ L,
    read_bytes(File, Len, Pkt),
    unpack(Pkt, Msg),
    '$inject_event'(Msg),
    receive(File).

db([], _).
db([add(Port, File, Ok)|S], Map) :-
    map:insert(Port, File, Map, Map2),
    when(Map2, Ok := []),
    db(S, Map2).
db([get(Port, File)|S], Map) :-
    map:lookup(Port, Map, File),
    db(S, Map).

loop([E|ES], DB) :- 
    handle(E, DB), 
    loop(ES, DB).

% internal events
handle(send_read(ID, PID), DB) :-
    current_node(SELF),
    when(SELF, send_msg(DB, PID, read(ID, PID, SELF))).
handle(send_value(ID, PID, X), DB) :-
    send_msg(DB, PID, value(ID, PID, X)).
handle(send_get_module(NID, MID, MOD), DB) :-
    send_msg(DB, NID, get_module(MID, MOD)).
handle(send_call(MID, IDX, ARGS, PEER), DB) :-
    '$resolve_peer'(PEER, PID),
    current_node(SELF),
    when(SELF, send_msg(DB, PID, call(MID, IDX, SELF, ARGS))).
handle(send_addref(PID, ID), DB) :-
    send_msg(DB, PID, addref(ID)).
handle(send_assign_port(PID, ID, X), DB) :-
    send_msg(DB, PID, assign_port(ID, X)).
% external events
handle(read(ID, SELF, PID), DB) :-
    '$get_exposed'(ID, X), 
    send_value(X, DB, PID, ID, SELF).  % suspends on X
handle(value(ID, OWNER, X), _) :- 
    '$assign_remote'(ID, OWNER, X).
handle(call(MID, IDX, NID, ARGS), _) :-
    '$retrieve_module'(MID, NID, MOD),
    '$call'(MOD, IDX, ARGS).
handle(get_module(MID, MOD), _) :-
    '$load_module'(MID, MOD).
handle(peer(PEER, NODE), _) :-
    '$register_peer'(PEER, NODE).
handle(exit(REASON), _) :-
    current_node(SELF, PID),
    fmt:format_chars("[~q:~q] terminated - ~q~n", [PID, SELF, REASON], Msg),
    list_to_string(Msg, Str),
    error(Str).
handle(addref(ID), _) :-
    '$add_reference'(ID).
handle(assign_port(ID, X), _) :-
    '$assign_port'(ID, X).
handle(E, _) :-
    otherwise |
    error(unkown_event(E)).

send_value(X, DB, PID, ID, SELF) :-
    data(X) |
    '$drop_reference'(ID),
    send_msg(DB, PID, value(ID, SELF, X)).

send_msg(DB, PID, Msg) :-
    send(DB, get(PID, File)),
    pack(Msg, Pkt),
    length(Pkt, Len),
    bytes_to_list(Pkt, Lst, []),
    H is Len >> 8,
    L is Len /\ 255,
    '$log'(send(PID, File, Pkt)),
    write_bytes(File, [H, L|Lst], _).
