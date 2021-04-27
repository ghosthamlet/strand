% OOP-style 9p server
%
% XXX exports...
%
% XXX messages...

-exports([start/1]).
-exports([root/2, entity/2, directory/4, static_file/5, file/5]).
-exports([data_source/3, data_sink/3]).
-exports([file_create/3]).

start(P) :-
    p9p:server(0, 1, TQ, RQ),
    loop(TQ, RQ, P, {}).

loop([], RQ, _, _) :- RQ := [].
loop([T|TQ], RQ, P, FT) :- 
    '$log'(T),
%    '$log'(fids(FT)),
    handle(T, TQ, RQ, P, FT).

handle(version(TAG, MSIZE, _), TQ, RQ, RP, _) :-
    RQ := [version(TAG, MSIZE, '9P2000')|RQ1],
    loop(TQ, RQ1, RP, {}).
handle(attach(TAG, FID, _, _, _), TQ, RQ, RP, FT) :-
    map:insert(FID, RP, FT, FT2),
    send(RP, qid(QID)),
    respond(QID, TAG, attach(TAG, QID), RQ, RQ1),
    loop(TQ, RQ1, RP, FT2).
handle(clunk(TAG, FID), TQ, RQ, RP, FT) :-
    map:delete(FID, FT, P, FT2),
    send(P, clunk),
    RQ := [clunk(TAG)|RQ1],
    loop(TQ, RQ1, RP, FT2).
handle(flush(TAG, _), TQ, RQ, RP, FT) :-
    RQ := [flush(TAG)|RQ1],
    loop(TQ, RQ1, RP, FT).
handle(open(TAG, FID, MODE), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, P),
    send(P, open(MODE, OP)),
    map:insert(FID, OP, FT, FT2),
    open(OP, TAG, RQ, RQ1),
    loop(TQ, RQ1, RP, FT2).
handle(create(TAG, FID, NAME, PERM, MODE), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, P),
    list_to_string(NAME, NSTR),
    send(P, create(NSTR, PERM, MODE, CP)),
    map:insert(FID, CP, FT, FT2),
    create(CP, TAG, RQ, RQ1),
    loop(TQ, RQ1, RP, FT2).
handle(read(TAG, FID, OFF, CNT), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, OP),
    send(OP, read(OFF, CNT, DATA)),
    respond(DATA, TAG, read(TAG, DATA), RQ, RQ1),
    loop(TQ, RQ1, RP, FT).
handle(write(TAG, FID, OFF, DATA), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, OP),
    send(OP, write(OFF, DATA, CNT)),
    respond(CNT, TAG, write(TAG, CNT), RQ, RQ1),
    loop(TQ, RQ1, RP, FT).
handle(stat(TAG, FID), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, P),
    send(P, stat(STAT)),
    respond(STAT, TAG, stat(TAG, STAT), RQ, RQ1),
    loop(TQ, RQ1, RP, FT).
handle(wstat(TAG, FID,STAT), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, P),
    send(P, wstat(STAT)),
    RQ := [wstat(TAG)|RQ1],
    loop(TQ, RQ1, RP, FT).
handle(walk(TAG, FID, NFID, NAMES), TQ, RQ, RP, FT) :-
    map:lookup(FID, FT, P),
    send(P, walk(NAMES, QIDS, NP)),
    handle_walk(NP, NFID, QIDS, TAG, FT, FT2, RQ, RQ1),
    loop(TQ, RQ1, RP, FT2).
handle(remove(TAG, FID), TQ, RQ, RP, FT) :-
    %XXX permissions
    map:delete(FID, FT, P, FT2),
    send(P, remove),
    RQ := [remove(TAG)|RQ1],
    loop(TQ, RQ1, RP, FT2).
handle(R, TQ, RQ, RP, FT) :-
    get_arg(2, R, TAG),
    fmt:format_chars("unhandled request: ~q", [R], MSG),
    RQ := [error(TAG, MSG)|RQ1],
    loop(TQ, RQ1, RP, FT).

respond(error(ERR), TAG, _, RQ, RQ1) :-
    RQ := [error(TAG, ERR)|RQ1].
respond(_, _, MSG, RQ, RQ1) :-
    otherwise | RQ := [MSG|RQ1].

open(error(ERR), TAG, RQ, RQ1) :-
    RQ := [error(TAG, ERR)|RQ1].
open(OP, TAG, RQ, RQ1) :-
    otherwise |
    send(OP, qid(QID)),
    RQ := [open(TAG, QID, 0)|RQ1].

create(error(ERR), TAG, RQ, RQ1) :-
    RQ := [error(TAG, ERR)|RQ1].
create(CP, TAG, RQ, RQ1) :-
    otherwise |
    send(CP, qid(QID)),
    RQ := [create(TAG, QID, 0)|RQ1].

handle_walk(error(ERR), _, _, TAG, FT, FT2, RQ, RQ1) :-
    FT2 := FT,
    RQ := [error(TAG, ERR)|RQ1].
handle_walk(NP, NFID, QIDS, TAG, FT, FT2, RQ, RQ1) :-
    otherwise |
    map:insert(NFID, NP, FT, FT2),
    RQ := [walk(TAG, QIDS)|RQ1].

% entity class

entity(STAT, SELF) :- 
    u9p:stat(STAT, STAT1),
    open_port(SELF, S), 
    entity(S, SELF, STAT1).

entity([], _, _).
entity([children(FS)|S], SELF, STAT) :-
    FS := {}, entity(S, SELF, STAT).
entity([clunk|S], SELF, STAT) :- 
    entity(S, SELF, STAT).
entity([qid(QID)|S], SELF, STAT) :- 
    get_arg(1, STAT, QID),
    entity(S, SELF, STAT).
entity([stat(ST)|S], SELF, STAT) :- 
    ST := STAT, entity(S, SELF, STAT).
entity([wstat(ST)|S], SELF, STAT) :-
    u9p:wstat(ST, STAT, STAT2),
    entity(S, SELF, STAT2).
entity([X|_], SELF, STAT) :- 
    string(X) |
    error(message_not_understood(X, SELF, STAT)).
entity([X|_], SELF, STAT) :- 
    tuple(X) |
    get_arg(1, X, M),
    error(message_not_understood(M, SELF, STAT)).

% root class -> entity

root(STAT, SELF) :-
    entity(STAT, SUPER),
    open_port(SELF, S),
    root(S, SELF, SUPER, {}).

root([], _, _, _).
root([add_child(NAME, F)|S], SELF, SUPER, FILES) :-
    map:insert(NAME, F, FILES, FS2),
    root(S, SELF, SUPER, FS2).
root([rm_child(NAME)|S], SELF, SUPER, FILES) :-
    map:delete(NAME, FILES, FS2),
    root(S, SELF, SUPER, FS2).
root([children(FS)|S], SELF, SUPER, FILES) :-
    FS := FILES,
    root(S, SELF, SUPER, FILES).
root([child(NAME, FP)|S], SELF, SUPER, FILES) :-
    map:lookup(NAME, FILES, FP),
    root(S, SELF, SUPER, FILES).
root([stat(STAT)|S], SELF, SUPER, FILES) :- 
    send(SUPER, stat(STAT)),
    root(S, SELF, SUPER, FILES).
root([open(_, OP)|S], SELF, SUPER, FILES) :- 
    map:values(FILES, FPS),
    stat_data(FPS, DATA),
    data_source(DATA, SELF, OP),
    root(S, SELF, SUPER, FILES).
root([create(NAME, PERM, _, OP)|S], SELF, SUPER, FILES) :- 
    send(SUPER, stat(STAT)),
    file_create(PERM, STAT, FSTAT),
    create_entity(NAME, PERM, FSTAT, [], SELF, OP),
    map:insert(NAME, OP, FILES, FS2),
    root(S, SELF, SUPER, FS2).
root([walk([], QIDS, OP)|S], SELF, SUPER, FILES) :- 
    QIDS := [], OP := SELF,
    root(S, SELF, SUPER, FILES).
root([walk(NAMES, QIDS, OP)|S], SELF, SUPER, FILES) :- 
    list(NAMES) |
    walk(NAMES, FILES, SELF, QIDS, OP),
    root(S, SELF, SUPER, FILES).
root([write(_, _, CNT)|S], SELF, SUPER, FILES) :-
    CNT := error('can not write to directory'),
    root(S, SELF, SUPER, FILES).
root([X|S], SELF, SUPER, FILES) :-
    otherwise | 
    send(SUPER, X), 
    root(S, SELF, SUPER, FILES).

walk([], _, LAST, QIDS, OP) :- 
    OP := LAST, QIDS := [].
walk([".."|NS], FILES, LAST, QIDS, OP) :-
    walk(NS, FILES, LAST, QIDS, OP).
walk([NAME|NS], FILES, LAST, QIDS, OP) :-
    NAME =\= ".." |
    list_to_string(NAME, NSTR),
    map:lookup(NSTR, FILES, OP1),
    walk2(OP1, NS, LAST, OP, QIDS).

walk2({}, _, _, OP, QIDS) :-
    OP := error('entity not found'), QIDS := [].
walk2(OP1, NS, _, OP, QIDS) :-
    OP1 =\= {} |
    send(OP1, qid(QID)),
    send(OP1, children(FILES)),
    QIDS := [QID|QIDS2],
    walk(NS, FILES, OP1, QIDS2, OP).

stat_data([], D) :- D := [].
stat_data([F|FS], D) :-
    send(F, stat(STAT)),
    p9p:build_stat(STAT, D, TL),
    stat_data(FS, TL).

create_entity(NAME, PERM, FSTAT, _, DIR, OP) :-
    (PERM >> 24) /\ 16'80 =:= 16'80 |
    directory(NAME, FSTAT, DIR, OP).
create_entity(NAME, _, FSTAT, DATA, DIR, OP) :-
    otherwise |
    static_file(NAME, FSTAT, DATA, DIR, OP).

file(STAT, DIR, SELF, SUPER, S) :-
    entity(STAT, SUPER),
    open_port(SELF, S),
    get_name(SUPER, NAME),
    send(DIR, add_child(NAME, SELF)).

file_create(PERM, DSTAT, FSTAT) :-
    %XXX permissions, check existance
    create_permissions(PERM, DSTAT, FSTAT).

create_permissions(PERM, {_, DPERM, _, _, _, _, _, _, _}, FSTAT) :-
    (PERM >> 24) /\ 16'80 =:= 16'80 |   % dir?
    P is PERM /\ (\8'777 \/ (DPERM /\ 8'777)),
    create_permissions2(P, d, FSTAT).
create_permissions(PERM, {_, DPERM, _, _, _, _, _, _, _}, FSTAT) :-
    otherwise |
    P is PERM /\ (\8'666 \/ (DPERM /\ 8'666)),
    create_permissions2(P, f, FSTAT).

create_permissions2(PERM, TYPE, FSTAT) :-
    u9p:gen_path(PATH),
    FSTAT := [perm(PERM), qid({TYPE, 0, PATH})].

% directory class -> root

directory(NAME, STAT, DIR, SELF) :-
    root([name(NAME)|STAT], SUPER),
    open_port(SELF, S),
    send(DIR, add_child(NAME, SELF)),
    directory2(S, SELF, SUPER, DIR).

directory2([], _, _, _).
directory2([remove|S], SELF, SUPER, DIR) :- 
    get_name(SELF, NAME),
    send(DIR, rm_child(NAME)),
    directory2(S, SELF, SUPER, DIR).
directory2([X|S], SELF, SUPER, DIR) :-
    otherwise | 
    send(SUPER, X), 
    directory2(S, SELF, SUPER, DIR).

directory_stat({{M, V, PATH}, P, AT, MT, _, NAME, UID, GID, MUID}, STAT) :-
    M2 is M \/ 16'80, P2 is P \/ 16'80000000,
    STAT := {{M2, V, PATH}, P2, AT, MT, 0, NAME, UID, GID, MUID}.

% static file class -> entity

static_file(NAME, STAT, DATA, DIR, SELF) :-
    file([name(NAME)|STAT], DIR, SELF, SUPER, S),
    static_file2(S, SELF, SUPER, DATA, DIR).

static_file2([], _, _, _, _).
static_file2([stat(STAT)|S], SELF, SUPER, DATA, DIR) :-
    send(SUPER, stat(STAT1)),
    length(DATA, LEN),
    stat_length(STAT1, LEN, STAT),
    static_file2(S, SELF, SUPER, DATA, DIR).
static_file2([open(M, OP)|S], SELF, SUPER, DATA, DIR) :-
    M /\ 16'0f =:= 0 |
    %XXX permissions?
    trunc_data(M, DATA, DATA2),
    data_source(DATA2, SELF, OP),
    static_file2(S, SELF, SUPER, DATA, DIR).
static_file2([open(M, OP)|S], SELF, SUPER, DATA, DIR) :-
    M >= 1, M =< 2 |
    %XXX permissions?
    trunc_data(M, DATA, DATA2),
    data_sink(DATA2, SELF, OP),
    static_file2(S, SELF, SUPER, DATA, DIR).
static_file2([remove|S], SELF, SUPER, DATA, DIR) :-
    get_name(SELF, NAME),
    send(DIR, rm_child(NAME)),
    static_file2(S, SELF, SUPER, DATA, DIR).
static_file2([set_data(DATA)|S], SELF, SUPER, _, DIR) :-
    static_file2(S, SELF, SUPER, DATA, DIR).
static_file2([X|S], SELF, SUPER, DATA, DIR) :-
    otherwise |
    send(SUPER, X),
    static_file2(S, SELF, SUPER, DATA, DIR).

msg(open(M, _), R) :- R := open(M).
msg(X, M) :- string(X) | M := X.
msg(X, M) :- tuple(X) | get_arg(1, X, M).

stat_length({QID, M, AT, MT, _, NAME, UID, GID, MUID}, LEN, STAT) :-
    STAT := {QID, M, AT, MT, LEN, NAME, UID, GID, MUID}.

get_name(P, NAME) :-
    send(P, stat(STAT)),
    get_arg(6, STAT, NAME).

trunc_data(M, _, D) :- M /\ 16'10 \=:= 0 | D := [].
trunc_data(_, D1, D) :- otherwise | D := D1.

data_source(DATA, FILE, SELF) :-
    open_port(SELF, S),
    data_source(S, SELF, FILE, DATA).

data_source([], _, _, _).
data_source([clunk|_], _, _, _).
data_source([read(OFF, CNT, D)|S], SELF, FILE, DATA) :-
    list:drop(OFF, DATA, D1),
    list:take(CNT, D1, D, []),
    data_source(S, SELF, FILE, DATA).
data_source([X|S], SELF, FILE, DATA) :-
    otherwise |
    send(FILE, X),
    data_source(S, SELF, FILE, DATA).

data_sink(DATA, FILE, SELF) :-
    open_port(SELF, S),
    length(DATA, LEN),
    data_sink(S, SELF, FILE, DATA, LEN).

data_sink([], _, _, _, _).
data_sink([clunk|_], _, _, _, _).
data_sink([read(OFF, CNT, D)|S], SELF, FILE, DATA, LEN) :-
    list:drop(OFF, DATA, D1),
    list:take(CNT, D1, D, []),
    data_sink(S, SELF, FILE, DATA, LEN).
data_sink([write(OFF, D, CNT)|S], SELF, FILE, DATA, LEN) :-
    length(D, CNT),
    add_data(OFF, D, DATA, LEN, CNT, DATA2, LEN2),
    send(FILE, set_data(DATA2)),
    data_sink(S, SELF, FILE, DATA2, LEN2).
data_sink([X|S], SELF, FILE, DATA, LEN) :-
    otherwise |
    send(FILE, X),
    data_sink(S, SELF, FILE, DATA, LEN).

add_data(OFF, D, DATA, LEN, CNT, DATA2, LEN2) :-
    OFF == LEN |
    list:append(DATA, D, DATA2),
    LEN2 is LEN + CNT.
add_data(OFF, D, DATA, LEN, CNT, DATA2, LEN2) :-
    OFF > LEN |
    PAD is OFF - LEN,
    list:times(PAD, 0, ZERO, D),
    list:append(DATA, ZERO, DATA2),
    LEN2 is LEN + PAD + CNT.
