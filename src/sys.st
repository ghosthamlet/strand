% base runtime system
%
% sys:mnode(MACHINE?, ADDR^)
%   Obtain address of first node on MACHINE.
%
% sys:map(MAP^)
%   Assigns a map of the form [[MACHINE, NODECOUNT, PEERMACHINE, ...], ...]
%   to MAP.
%
% sys:ping(MACHINE?, NODE?, ADDR^)
%   Try to access given node, assigns address or error message to ADDR.
%
% sys:topology(TYPE?, TOP^)
%   Computes a topology of type 'ring' or 'torus' and assigns peers to all nodes.
%   TOP holds the built mapping.
%
% sys:execute(MODULE?, TTYPE?, STATUS^)
%   Execute MODULE:main/0 in topology TTYPE and return status in STATUS.
%
% sys:nodes(ALL^)
%   Assigns a list of the addresses of all nodes in the network to ALL.

-exports(['$start'/0, mnode/2, map/1, ping/3, topology/2, execute/3, nodes/1,
    statistics/1]).

'$start' :-
    command_line(ARGS),
    parse_args(ARGS, Info),
    '$events'(ES), 
    loop(ES, Info).

parse_args(['-vm', Nodes|Rmac], Info) :-
    string_to_integer(Nodes, Nodes2),
    intlist(Rmac, Rmac2),
    Info := [Nodes2|Rmac2].
parse_args(_, Info) :- otherwise | Info := [].

intlist([], L) :- L := [].
intlist([N|L1], L) :-
    string_to_integer(N, I),
    L := [I|L2],
    intlist(L1, L2).

loop([get_info(R)|ES], Info) :- 
    R := Info,
    loop(ES, Info).
loop([E|ES], Info) :- 
    otherwise |
    handle(E), 
    loop(ES, Info).

% internal events
handle(send_read(ID, PID)) :-
    current_node(SELF), 
    send_with(SELF, PID, read(ID, PID, SELF)).
handle(send_value(ID, PID, X)) :-
    '$send'(PID, value(ID, PID, X)).
handle(send_get_module(NID, MID, MOD)) :-
    '$send'(NID, get_module(MID, MOD)).
handle(send_call(MID, IDX, ARGS, all)) :-
    current_node(SELF),
    broadcast(SELF, call(MID, IDX, SELF, ARGS)).
handle(send_call(MID, IDX, ARGS, PEER)) :-
    PEER =\= all |
    '$resolve_peer'(PEER, PID),
    current_node(SELF),
    send_with(SELF, PID, call(MID, IDX, SELF, ARGS)).
handle(send_addref(PID, ID)) :-
    '$send'(PID, addref(ID)).
handle(send_assign_port(PID, ID, X)) :-
    '$send'(PID, assign_port(ID, X)).
% external events
handle(read(ID, SELF, PID)) :-
    '$get_exposed'(ID, X), 
    send_value(X, PID, ID, SELF).  % suspends on X
handle(value(ID, OWNER, X)) :- 
    '$assign_remote'(ID, OWNER, X).
handle(call(MID, IDX, NID, ARGS)) :-
    '$retrieve_module'(MID, NID, MOD),
    '$call'(MOD, IDX, ARGS).
handle(get_module(MID, MOD)) :-
    '$load_module'(MID, MOD).
handle(peer(PEER, NODE)) :-
    '$register_peer'(PEER, NODE).
handle(exit(REASON)) :-
    current_node(SELF, PID),
    fmt:format_chars("[~q:~q] terminated - ~q~n", [PID, SELF, REASON], Msg),
    list_to_string(Msg, Str),
    error(Str).
handle(addref(ID)) :-
    '$add_reference'(ID).
handle(assign_port(ID, X)) :-
    '$assign_port'(ID, X).
handle(get_nodes(All)) :-   % assumes this node is leader
    get_global('$all_nodes', All).
handle(E) :-
    otherwise |
    error(unkown_event(E)).

send_with(SELF, DEST, MSG) :- 
    data(SELF) | '$send'(DEST, MSG).

send_value(X, PID, ID, SELF) :-
    data(X) |
    '$drop_reference'(ID),
    '$send'(PID, value(ID, SELF, X)).

broadcast(Self, Call) :-
    data(Self) |
    nodes(All),
    broadcast2(All, Call).
    
broadcast2([], _).
broadcast2([PID|ALL], CALL) :-
    '$send'(PID, CALL),
    broadcast2(ALL, CALL).

mnode(MAC, Addr) :- Addr is (MAC << 8) \/ 32.

map(MAP) :- build_map([1], [], MAP).

build_map([], MAP1, MAP) :- MAP := MAP1.
build_map([MAC|MS], MAP1, MAP) :-
    build_map1(MAP1, MAC, MS, MAP1, MAP).

build_map1([], MAC, MS, MAP1, MAP) :-
    mnode(MAC, A),
    '$send'(A, get_info(R)),
    build_map2(R, MAC, MS, MAP1, MAP).
build_map1([[MAC|_]|_], MAC, MS, MAP1, MAP) :-
    build_map(MS, MAP1, MAP).
build_map1([[MAC1|_]|M1], MAC, MS, MAP1, MAP) :-
    MAC1 =\= MAC |
    build_map1(M1, MAC, MS, MAP1, MAP).

build_map2([NODES|RMACS], MAC, MS, MAP1, MAP) :-
    list:append(RMACS, MS, MS2),
    build_map(MS2, [[MAC, NODES|RMACS]|MAP1], MAP).

nodes(All) :-
    get_global('$all_nodes', All1, none),
    current_node(Addr),
    mnode(1, Leader),
    nodes(All1, Addr, Leader, All).

nodes(All1, _, _, All) :- list(All1) | All := All1.
nodes(none, Leader, Leader, All) :-
    map(Map),
    nodelist(Map, All),
    put_global('$all_nodes', All, _).
nodes(none, Addr, Leader, All) :-
    Addr =\= Leader |
    '$send'(Leader, get_nodes(All2)),
    put_global('$all_nodes', All2, _),
    All := All2.

collect_nodes(All) :-
    map(Map),
    nodelist(Map, All),
    put_global('$all_nodes', All, _).

ping(Mac, Node, R) :-
    current_node(Addr), This := Addr >> 8,
    ping(Mac, This, Node, R).

ping(Mac, Mac, Node, R) :-
    '$message_port_owner'(Node, R).
ping(Mac, This, Node, R) :-
    Mac =\= This |
    Dest is (Mac << 8) \/ Node,
    ping_remote(R)@Dest,
    wait(5, To),
    timeout(To, R).

topology(Type, Top) :-
    collect_nodes(All),
    build_topology(Type, All, Top1),
    deref(Top1, Derefd),
    topology(Derefd, Top1, Top).

topology([], Top1, Top) :- 
    register_peers(Top1, Start),
    when(Start, Top := Top1).

nodelist([], All) :- All := [].
nodelist([[Mac, Nodes|_]|Map], All) :-
    nodelist2(Nodes, Mac, Map, All).

nodelist2(0, _, Map, All) :- nodelist(Map, All).
nodelist2(N, Mac, Map, All) :-
    N > 0 |
    Addr is (Mac << 8) \/ (31 + N),
    All := [Addr|All2],
    N2 is N - 1,
    nodelist2(N2, Mac, Map, All2).

build_topology(ring, All, T) :- topology:ring(All, T).
build_topology(torus, All, T) :- topology:torus(All, T).

register_peers([], Prev) :- Prev := [].
register_peers([[Addr|Peers]|T], Prev) :-
    register_peers2(Peers, Prev, Next)@Addr,
    register_peers(T, Next).

register_peers2([], Prev, Next) :- Prev := Next.
register_peers2([[Peer|Addr]|Peers], Prev, Next) :-
    '$register_peer'(Peer, Addr),
    register_peers2(Peers, Prev, Next).

timeout(To, R) :- data(To), unknown(R) | R := 'unreachable node'.
timeout(To, R) :- data(To), known(R) | true.

ping_remote(R) :- current_node(_, R).

wait(Seconds, Done) :-
    %XXX use timer here
    fmt:format_chars("sleep ~d", [Seconds], Cmd),
    shell(Cmd, Done).

execute(Module, TType, Status) :-
    mnode(1, Node),
    topology(TType, Top),
    execute(Top, Node, Module, Status).

execute(Top, Node, Module, Status) :-
    data(Top) | execute2(Module, Status)@Node.

execute2(Module, Status) :- 
    run(Module, main, S, _),
    Status := S.

statistics(S) :- '$statistics'(S).
