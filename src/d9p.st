% Expose data structure as 9P read-only tree

server(Data) :-
    p9p:server(0, 1, TQ, RQ),
    make_entity(Data, EData),
    loop(TQ, RQ, EData, {}).

loop([], RQ, _, _) :- RQ := [].
loop([T|TQ], RQ, Data, FT) :-
    '$log'(T),
    handle(T, TQ, RQ, Data, FT).

handle(version(TAG, MSIZE, _), TQ, RQ, E, _) :-
    RQ := [version(TAG, MSIZE, '9P2000')|RQ1],
    loop(TQ, RQ1, E, {}).
handle(attach(TAG, FID, _, _, _), TQ, RQ, E, FT) :-
    entity_qid(E, QID),
    map:insert(FID, E, FT, FT2),
    respond(QID, TAG, attach(TAG, QID), RQ, RQ1),
    loop(TQ, RQ1, E, FT2).
handle(clunk(TAG, FID), TQ, RQ, E, FT) :-
    map:delete(FID, FT, FT2),
    RQ := [clunk(TAG)|RQ1],
    loop(TQ, RQ1, E, FT2).
handle(flush(TAG, _), TQ, RQ, E, FT) :-
    RQ := [flush(TAG)|RQ1],
    loop(TQ, RQ1, E, FT).
handle(open(TAG, FID, MODE), TQ, RQ, E, FT) :-
    map:lookup(FID, FT, E2),
    open_entity(E2, MODE, E3),
    handle_open(E3, FID, QID, FT, FT2),
    respond(E3, TAG, open(TAG, QID, 0), RQ, RQ1),
    loop(TQ, RQ1, E, FT2).
handle(read(TAG, FID, OFF, CNT), TQ, RQ, E, FT) :-
    map:lookup(FID, FT, E2),
    read_entity(E2, OFF, CNT, RData),
    respond(RData, TAG, read(TAG, RData), RQ, RQ1),
    loop(TQ, RQ1, E, FT).
handle(stat(TAG, FID), TQ, RQ, E, FT) :-
    map:lookup(FID, FT, E2),
    entity_stat(E2, STAT),
    respond(STAT, TAG, stat(TAG, STAT), RQ, RQ1),
    loop(TQ, RQ1, E, FT).
handle(walk(TAG, FID, NFID, NAMES), TQ, RQ, E, FT) :-
    map:lookup(FID, FT, E2),
    walk_entity(E2, NAMES, QIDS, E3),
    handle_walk(E3, NFID, QIDS, TAG, FT, FT2, RQ, RQ1),
    loop(TQ, RQ1, E, FT2).
handle(R, TQ, RQ, E, FT) :-
    get_arg(2, R, TAG),
    fmt:format_chars("unhandled request: ~q", [R], MSG),
    RQ := [error(TAG, MSG)|RQ1],
    loop(TQ, RQ1, E, FT).

handle_open(error(_), _, _, FT1, FT) :- FT := FT1.
handle_open(E, FID, QID, FT1, FT) :-
    otherwise |    
    entity_qid(E, QID),
    map:insert(FID, E, FT1, FT).

respond(error(ERR), TAG, _, RQ, RQ1) :-
    RQ := [error(TAG, ERR)|RQ1].
respond(_, _, MSG, RQ, RQ1) :-
    otherwise | RQ := [MSG|RQ1].

handle_walk(error(ERR), _, _, TAG, FT, FT2, RQ, RQ1) :-
    FT2 := FT,
    RQ := [error(TAG, ERR)|RQ1].
handle_walk(E, NFID, QIDS, TAG, FT, FT2, RQ, RQ1) :-
    otherwise |
    map:insert(NFID, E, FT, FT2),
    RQ := [walk(TAG, QIDS)|RQ1].

make_entity(d(Name, Data), E) :-
    u9p:stat([d, perm('dr-xr-xr-x'), qid(d), name(Name)], Stat),
    make_entities(Data, ES),
    E := d(Stat, ES).
make_entity(f(Name, Data), E) :-
    u9p:stat([perm('r--r--r--'), qid(f), name(Name)], Stat),
    E := f(Stat, Data).

make_entities([], ES) :- ES := [].
make_entities([X|L], ES) :- 
    make_entity(X, E), ES := [E|ES2], make_entities(L, ES2).

open_entity(d(Stat, ES), _, E) :-
    stat_data(ES, SData),
    list_to_bytes(SData, SData2),
    E := f(Stat, SData2).
open_entity(f(Stat, Data), 0, E) :-
    serialize_data(Data, SData),
    E := f(Stat, SData).
open_entity(f(_, _), Mode, E) :-
    Mode =\= 0 |
    E := error('no write permission').
open_entity(_, _, E) :- E := error('open failed').

stat_data([], D) :- D := [].
stat_data([F|FS], D) :-
    entity_stat(F, Stat),
    p9p:build_stat(Stat, D, TL),
    stat_data(FS, TL).

entity_qid(E, QID) :- entity_stat(E, Stat), get_arg(1, Stat, QID).
entity_stat(E, S) :- get_arg(2, E, S).
entity_data(E, D) :- get_arg(3, E, D).

read_entity(E, Off, Cnt,  RData) :-
    entity_data(E, Data),
    length(Data, Len),
    extract(Off, Cnt, Len, Data, RData).

extract(_, 0, _, _, RData) :- RData := [].
extract(Off, _, Len, _, RData) :- Off >= Len | RData := [].
extract(Off, Cnt, Len, Data, RData) :- 
    Off + Cnt > Len | 
    Cnt2 is Len - Off,
    P is Off + 1,
    get_bytes(P, Data, Cnt2, RData, []).
extract(Off, Cnt, _, Data, RData) :- 
    otherwise | 
    P is Off + 1,
    get_bytes(P, Data, Cnt, RData, []).

walk_entity(E, [], QIDs, E2) :- QIDs := [], E2 := E.
walk_entity(d(_, ES), [Name|Names], QIDs, E2) :-
    list_to_string(Name, SName),
    walk_dir(ES, SName, Names, QIDs, E2).

walk_dir([], _, _, QIDs, E2) :- QIDs := [], E2 := error('file not found').
walk_dir([E|ES], Name, Names, QIDs, E2) :-
    entity_stat(E, Stat),
    get_arg(6, Stat, Name1),
    walk_dir2(Name1, Name, Names, E, Stat, ES, QIDs, E2).

walk_dir2(Name, Name, Names, E, Stat, _, QIDs, E2) :-
    get_arg(1, Stat, QID),
    QIDs := [QID|QIDs2],
    walk_entity(E, Names, QIDs2, E2).
walk_dir2(Name1, Name, Names, _, _, ES, QIDs, E2) :-
    Name1 =\= Name |
    walk_dir(ES, Name, Names, QIDs, E2).

serialize_data(X, B) :-
    collect_data(X, L, [], 0, Len),
    make_bytes(Len, B),
    concat(L, 1, B).
 
collect_data(X, D, TL, Len1, Len) :-
    integer(X) | 
    fmt:format_chars("~d", [X], L), 
    D := [L|TL],
    length(L, Len0),
    Len is Len1 + Len0.
collect_data(X, D, TL, Len1, Len) :- 
    bytes(X) | collect_binary(X, D, TL, Len1, Len).
collect_data(X, D, TL, Len1, Len) :- 
    string(X) | collect_binary(X, D, TL, Len1, Len).
collect_data([], D, TL, Len1, Len) :- D := TL, Len := Len1.
collect_data(X, D, TL, Len1, Len) :- 
    list(X) | collect_lines(X, D, TL, Len1, Len).

collect_binary(X, D, TL, Len1, Len) :- 
    D := [X|TL], 
    length(X, Len0),
    Len is Len1 + Len0.

collect_lines([], D, TL, Len1, Len) :- D := TL, Len := Len1.
collect_lines([X|L], D, TL, Len1, Len) :-
    collect_data(X, D, [#0a|TL1], Len1, Len2),
    Len3 is Len2 + 1,
    collect_lines(L, TL1, TL, Len3, Len).

concat([], _, _).
concat([X|L], P, B) :-
    '$put_bytes'(P, B, X, Ok),
    length(X, Len),
    P2 is P + Len,
    concat2(Ok, L, P2, B).

concat2([], L, P2, B) :- concat(L, P2, B).
