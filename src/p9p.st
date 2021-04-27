% 9p protocol - general message parsing and -construction.
%
%   p9p:client(IN?, OUT?, MQ?, MSIZE?, DONE^)
%       Start a 9p client, writing requests to file OUT and reading replies
%       from file IN. MQ is a stream that should receive 9p requests which
%       are sent to the server. MSIZE holds a suggested maximum message
%       size. When the server closes the connection, the empty list is assigned
%       to DONE.
%
%   p9p:server(IN?, OUT?, RQ?, TQ?)
%       Start a 9p server, reading requests from file IN and writing responses
%       to file OUT. RQ will be a stream containing 9p requests from the
%       server. The stream TQ takes responses for client requests.
%
%   p9p:build_stat(STATINFO?, BYTES^[, TAIL?])
%       Converts a tuple with stat-information of a file into a string of bytes.
%       STATINFO should have the following form:
%           {QID, MODE, ATIME, MTIME, LEN, NAME, UID, GID, MUID}
%       where QID is a 3-tuple {MODE, VERSION, PATH}, PATH is a list
%       of 8 bytes, NAME, UID, GID and MUID are strings or character lists
%       and all other values are integers.
%
%   p9p:parse_stat(BYTES?, STAT^, RBYTES^)
%       Parses stat-information from the byte-stream BYTES and assigns the
%       result tuple to STAT, which has the same form as for build_stat/2.
%       RBYTES holds the remaining bytes from the input stream.
%
% Client requests:
%
%   clunk(FID, TAG, R)      R = []
%   flush(OTAG, TAG, R)     R = []
%   open(FID, MODE, TAG, R)         R = {QID, IOUNIT}
%   create(FID, NAME, PERM, MODE, TAG, R)       R = {QID, IOUNIT}
%   read(FID, OFF, CNT, TAG, R)     R = DATA
%   write(FID, OFF, DATA, TAG, R)   R = CNT'
%   remove(FID, TAG, R)     R = []
%   stat(FID, TAG, R)       R = STATINFO
%   wstat(FID, STAT, TAG, R)    R = []
%   walk(FID, NFID, NAMES, TAG, R)      R = [QID, ...]
%
%       R may also be the term error(MSG).
%
% Server requests:
%
%   version(TAG, MSIZE, V)
%   attach(TAG, FID, AFID, UNAME, ANAME)
%   auth(TAG, AFID, UNAME, ANAME)
%   clunk(TAG, FID)
%   flush(TAG, OTAG)
%   open(TAG, FID, MODE)
%   create(TAG, FID, NAME, PERM, MODE)
%   read(TAG, FID, OFF, CNT)
%   write(TAG, FID, OFF, DATA)
%   remove(TAG, FID)
%   stat(TAG, FID)
%   wstat(TAG, FID, STAT)
%   walk(TAG, FID, NFID, NAMES)
%
% Server replies:
%
%   version(TAG, MSIZE, V)
%   auth(TAG, QID)
%   attach(TAG, QID)
%   clunk(TAG)
%   error(TAG, MSG)
%   flush(TAG)
%   open(TAG, QID, IOUNIT)
%   create(TAG, QID, IOUNIT)
%   read(TAG, DATA)
%   write(TAG, CNT)
%   remove(TAG)
%   stat(TAG, STAT)
%   wstat(TAG)
%   walk(TAG, [QID, ...])
%
% Constraints:
%  
%  * intro(5)
%      - Filenames may not contain the "/" character or <32, >127.
%      - Tversion cancels all outstanding I/O.
%      - All requests on a connection share the same FID space.
%      - If normal operation exceeds msg-size limit, send Rerror.
%      - Walk in a directory requires exec permissions.
%      - DMEXCL: only one client may have access.
%      - synthetic files have qid.version 0 by convention.
%  * auth(5)
%      - aname specifies tree to access.
%      - no auth: use afid ~0.
%  * clunk(5)
%      - delete file if ORCLOSE.
%  * flush(5)
%      - multiple flushes for same oldtag: answer in identical order
%         (last flush request is sufficient).
%  * open(5)
%      - OTRUNC on DMAPPEND file has no effect.
%      - write/trunc/ORCLOSE of directory is illegal.
%      - create requires write permissions for directory.
%      - create: group of the file is the same as dir.
%      - create: permissions are the value of
%                      perm & (~0666 | (dir.perm & 0666))
%            if a regular file is being created and
%                      perm & (~0777 | (dir.perm & 0777))
%            if a directory is created.
%      - creation of "." or ".." is illegal.
%      - if fid is already open, open/create fails.
%      - create already existing is illegal (use open + trunc).
%      - iounit may be 0 to use attach msize.
%  * read(5)
%      - offset > size: return zero bytes.
%      - read dir: return stat entries.
%      - write: append-only ignores offset.
%      - directories may not be written.
%  * remove(5)
%      - needs write permissions for dir.
%      - always clunks the fid.
%  * stat(5)
%      - servers may timeout an exclusive access to a file.
%      - mtime (file): last write, create, open+trunc.
%      - mtime (dir): last remove, create, wstat in that dir.
%      - atime (file): last read, also set with mtime.
%      - atime (dir): last attach, walk, create.
%      - muid: last user who change mtime.
%      - dirs have conventional length of 0.
%      - stat does not require permissions.
%      - wstat: name may be changed with write permission in parent dir.
%      - wstat: length may be changed with write permission.
%      - wstat: change length of dir to !=0 is illegal.
%      - wstat: mode/mtime may be changed by owner/group leader.
%      - wstat: may not change dir bit.
%      - wstat: GID may be changed by owner, if member of new group
%         or by current group leader if member of new group.
%      - all other items may not be changed, including owner.
%      - wstat: either all changes succeed or none.
%      - wstat: handle "don't care" values.
%      - wstat: all don't-care => commit file to storage.
%  * walk(5)
%      - fid must be directory unless zero path entries are given.
%      - fid must not be open/created.
%      - "." is not used, ".." means parent.
%      - ".." in root returns root.
%      - at most 16 path entries.

-exports([client/5, server/4, build_stat/2, build_stat/3, parse_stat/3]).

put_string(S, S9, TL) :-
    string(S) | 
    string_to_byte_list(S, L, TL), 
    length(S, NL),
    put_int16(NL, S9, L).
put_string(S, S9, TL) :-
    bytes(S) | 
    bytes_to_list(S, L, TL), 
    length(S, NL),
    put_int16(NL, S9, L).
put_string(I, S9, TL) :-
    integer(I) | integer_to_list(I, L), put_string(L, S9, TL).
put_string(S, S9, TL) :-
    otherwise |
    length(S, L),
    put_int16(L, S9, R),
    list:append(S, TL, R).

put_strings([], L, TL) :- L := TL.
put_strings([S|R], L, TL) :-
    put_string(S, L, L2),
    put_strings(R, L2, TL).

put_int16(N, L, TL) :-
    N1 is N /\ 255, N2 is (N >> 8) /\ 255,
    L := [N1, N2|TL].

put_int32(N, L, TL) :-
    N1 is N /\ 16'ffff,
    N2 is (N >> 16) /\ 16'ffff,
    put_int16(N1, L, TL1),
    put_int16(N2, TL1, TL).

put_int64(N, L, TL) :-
    N1 is N /\ 16'ffffffff,
    N2 is (N >> 32) /\ 16'ffffffff,
    put_int32(N1, L, TL1),
    put_int32(N2, TL1, TL).

put_qid({T, V, P}, L, TL) :-
    L := [T|L1],
    put_int32(V, L1, L2),
    list:append(P, TL, L2).

put_header(SZ, TYPE, TAG, L, TL) :-
    put_int32(SZ, L, [TYPE|L1]),
    put_int16(TAG, L1, TL).

get_string(S, STR, R) :-
    get_int16(S, L, S2),
    list:cut(L, S2, [], STR, R).

get_strings(0, S, SL, R) :- SL := [], R := S.
get_strings(N, S, SL, R) :-
    N > 0 | 
    get_string(S, S1, SR), 
    SL := [S1|SL2], 
    N2 is N - 1,
    get_strings(N2, SR, SL2, R).

get_int16([N1, N2|R1], N, R) :-
    N is N1 \/ (N2 << 8), R := R1.

get_int32(R1, N, R) :-
    get_int16(R1, N1, R2),
    get_int16(R2, N2, R),
    N is (N2 << 16) \/ N1.

get_int64(R1, N, R) :-
    get_int32(R1, N1, R2),
    get_int32(R2, N2, R),
    N is (N2 << 32) \/ N1.

get_qid([T|R1], QID, R) :-
    QID := {T, V, P},
    get_int32(R1, V, R2),
    list:cut(8, R2, [], P, R).

get_header(S, SZ, TYPE, TAG, R) :-
    get_int32(S, SZ, S1),
    get_header(S1, TYPE, TAG, R).

get_header([T|S], TYPE, TAG, R) :-
    TYPE := T, get_int16(S, TAG, R). 

% size of payload + total size + tag + type
msg_size(MSG, SZ) :- length(MSG, L), SZ is L + 7.

% client interface

client(I, O, MQ, MSIZE, DONE) :- 
    merger([merge(TQ1), merge(TQ2)], TQ),
    write_requests([version(1000000, '9P2000', VR)|MQ], -1, O, TQ1),
    process_transactions(TQ, [], DONE),
    read_replies(I, TQ2),
    negotiate_protocol(VR, MSIZE).

write_requests([M|MQ], TC, O, TQ) :-
    write_request(M, TC, O, TQ, TQ2, OK),
    write_requests(OK, MQ, TC, O, TQ2).

write_requests([], MQ, TC, O, TQ) :- 
    TC2 is TC + 1,
    write_requests(MQ, TC2, O, TQ).

write_request(version(MSIZE, V, R), TC, O, TQ1, TQ, OK) :-
    put_int32(MSIZE, M1, M2),
    put_string(V, M2, []),
    write_request_msg(M1, 100, TC, _, R, O, TQ1, TQ, OK).
write_request(auth(AFID, UNAME, ANAME, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(AFID, M1, M2),
    put_string(UNAME, M2, M3),
    put_string(ANAME, M3, []),
    write_request_msg(M1, 102, TC, TAG, R, O, TQ1, TQ, OK).
write_request(attach(FID, AFID, UNAME, ANAME, TAG, R), TC, O, TQ1, TQ, 
    OK) :-
    put_int32(FID, M1, M2),
    put_int32(AFID, M2, M3),
    put_string(UNAME, M3, M4),
    put_string(ANAME, M4, []),
    write_request_msg(M1, 104, TC, TAG, R, O, TQ1, TQ, OK).
write_request(clunk(FID, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, []),
    write_request_msg(M1, 120, TC, TAG, R, O, TQ1, TQ, OK).
write_request(flush(OTAG, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int16(OTAG, M1, []),
    write_request_msg(M1, 108, TC, TAG, R, O, TQ1, TQ, OK).
write_request(open(FID, MODE, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, [MODE]),
    write_request_msg(M1, 112, TC, TAG, R, O, TQ1, TQ, OK).
write_request(create(FID, NAME, PERM, MODE, TAG, R), TC, O, TQ1, TQ, 
    OK) :-
    put_int32(FID, M1, M2),
    put_string(NAME, M2, M3),
    put_int32(PERM, M3, [MODE]),
    write_request_msg(M1, 114, TC, TAG, R, O, TQ1, TQ, OK).
write_request(read(FID, OFF, CNT, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, M2),
    put_int64(OFF, M2, M3),
    put_int32(CNT, M3, []),
    write_request_msg(M1, 116, TC, TAG, R, O, TQ1, TQ, OK).
write_request(write(FID, OFF, DATA, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, M2),
    put_int64(OFF, M2, M3),
    build_data(DATA, CNT, BYTES),
    put_int32(CNT, M3, BYTES),
    write_request_msg(M1, 118, TC, TAG, R, O, TQ1, TQ, OK).
write_request(remove(FID, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, []),
    write_request_msg(M1, 122, TC, TAG, R, O, TQ1, TQ, OK).
write_request(stat(FID, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, []),
    write_request_msg(M1, 124, TC, TAG, R, O, TQ1, TQ, OK).
write_request(wstat(FID, STAT, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, M2),
    build_stat(STAT, SBYTES),
    length(SBYTES, CNT),
    put_int16(CNT, M2, SBYTES),
    write_request_msg(M1, 126, TC, TAG, R, O, TQ1, TQ, OK).
write_request(walk(FID, NFID, NAMES, TAG, R), TC, O, TQ1, TQ, OK) :-
    put_int32(FID, M1, M2),
    put_int32(NFID, M2, M3),
    length(NAMES, CNT),
    put_int16(CNT, M3, M4),
    put_strings(NAMES, M4, []),
    write_request_msg(M1, 110, TC, TAG, R, O, TQ1, TQ, OK).
write_request(M, _, _, _, _, _) :-
    error(invalid_request(M)).

write_request_msg(MSG, TYPE, TC, TAG, R, O, TQ1, TQ, OK) :-
    TQ1 := [add(TC, R)|TQ],
    TAG := TC,
    msg_size(MSG, SZ),
    put_header(SZ, TYPE, TC, M, MSG),
    write_bytes(O, M, OK).

build_stat({QID, MODE, ATIME, MTIME, LEN, NAME, UID, GID, MUID},
    BYTES, TL) :-   
    put_int16(-1, B1, B2),  % type
    put_int32(-1, B2, B3),   % dev
    put_qid(QID, B3, B5),
    put_int32(MODE, B5, B6),
    put_int32(ATIME, B6, B7),
    put_int32(MTIME, B7, B8),
    put_int64(LEN, B8, B9),
    put_strings([NAME, UID, GID, MUID], B9, TL),
    put_int16(SZ, BYTES, B1),
    length(NAME, NAMELEN),
    length(UID, UIDLEN),
    length(GID, GIDLEN),
    length(MUID, MUIDLEN),
    SZ is 2 + 4 + 13 + 4 + 4 + 4 + 8 + 2 + NAMELEN + 2 + UIDLEN + 2 + GIDLEN + 2 + MUIDLEN.
build_stat({MODE, MTIME, LEN, NAME, UID, GID}, BYTES, TL) :-
    build_stat({{-1, -1, [-1, -1, -1, -1, -1, -1, -1, -1]}, MODE, -1, MTIME, LEN,
        NAME, UID, GID, ''}, BYTES, TL).

build_stat(STAT, BYTES) :- build_stat(STAT, BYTES, []).

build_data(X, CNT, BYTES) :-
    string(X) |
    string_to_byte_list(X, BYTES, []),
    length(BYTES, CNT).
build_data(X, CNT, BYTES) :-
    integer(X) |
    integer_to_list(X, BYTES),
    length(BYTES, CNT).
build_data(X, CNT, BYTES) :-
    otherwise |
    string_to_byte_list(X, BYTES, []),
    length(BYTES, CNT).

process_transactions([], _, DONE) :- DONE := [].
process_transactions([add(TAG, R)|TQ], PEND, DONE) :-
    process_transactions(TQ, [{TAG, R}|PEND], DONE).
process_transactions([rem(TAG, R)|TQ], PEND, DONE) :-
    pending_transaction(PEND, TAG, R, PEND2, PEND2, TQ, DONE).

pending_transaction([], TAG, _, _, _, _, _) :-
    error(unknown_transaction(TAG)).
pending_transaction([{TAG, V}|PEND], TAG, R, PEND1, PEND2, TQ, DONE) :-
    V := R, PEND2 := PEND, 
    process_transactions(TQ, PEND1, DONE).
pending_transaction([PE|PEND], TAG, R, PEND1, PEND2, TQ, DONE) :-
    otherwise |
    PEND2 := [PE|PEND3],
    pending_transaction(PEND, TAG, R, PEND1, PEND3, TQ, DONE).

read_replies(FD, TQ) :-
    io:read_byte_stream(FD, S),
    read_replies2(S, TQ).

read_replies2([], TQ) :- TQ := [].
read_replies2(S, TQ) :-
    otherwise |
    get_header(S, SZ, TYPE, TAG, R),
    PS is SZ - 7,
    list:cut(PS, R, [], MSG, R2),
    parse_reply(TYPE, MSG, REPLY),
    TQ := [rem(TAG, REPLY)|TQ1],
    read_replies2(R2, TQ1).

parse_reply(101, MSG, R) :-      % Rversion
    get_int32(MSG, MSZ, M1),
    get_string(M1, V, _),
    R := {MSZ, V}.
parse_reply(103, MSG, R) :-      % Rauth
    get_qid(MSG, R, _).
parse_reply(105, MSG, R) :-      % Rattach
    get_qid(MSG, R, _).
parse_reply(121, _, R) :-      % Rclunk
    R := [].
parse_reply(107, MSG, R) :-    % Rerror
    get_string(MSG, M, _),
    R := error(M).
parse_reply(109, _, R) :-     % Rflush
    R := [].
parse_reply(113, MSG, R) :-     % Ropen
    get_qid(MSG, QID, M1),
    get_int32(M1, IOUNIT, _),
    R := {QID, IOUNIT}.
parse_reply(115, MSG, R) :-     % Rcreate
    get_qid(MSG, QID, M1),
    get_int32(M1, IOUNIT, _),
    R := {QID, IOUNIT}.
parse_reply(117, MSG, R) :-     % Rread
    get_int32(MSG, _, R).
parse_reply(119, MSG, R) :-     % Rwrite
    get_int32(MSG, R, _).
parse_reply(123, _, R) :-     % Rremove
    R := [].
parse_reply(125, MSG, R) :-     % Rstat
    parse_stat(MSG, R, _).
parse_reply(127, _, R) :-       % Rwstat
    R := [].
parse_reply(111, MSG, R) :-     % Rwalk
    get_int16(MSG, NWQ, M1),
    parse_nqids(NWQ, M1, R).
parse_reply(T, MSG, R) :-
    otherwise | R := invalid_reply(T, MSG).

negotiate_protocol({MSIZE, V}, MSZ) :-
    MSIZE =< 10000000 |
    MSZ := MSIZE, check_version(V).
negotiate_protocol({MSIZE, _}, _) :- 
    otherwise | error(protocol_error(msize(MSIZE))).

check_version(V) :-
    list:scan(V, 0'., V2, []),
    check_version2(V2).

check_version2("9P2000").
check_version2(V) :- otherwise | error(protocol_error(version(V))).

parse_nqids(0, _, R) :- R := [].
parse_nqids(N, MSG, R) :-
    N > 0 | 
    get_qid(MSG, QID, M1),
    R := [QID|R2],
    N2 is N - 1,
    parse_nqids(N2, M1, R2).

parse_stat(M, STAT, MR) :-
    get_int16(M, _, M1),
    get_int16(M1, _, M2),
    get_int32(M2, _, M3),
    get_qid(M3, QID, M4),
    get_int32(M4, MODE, M5),
    get_int32(M5, ATIME, M6),
    get_int32(M6, MTIME, M7),
    get_int64(M7, LEN, M8),
    get_string(M8, NAME, M9),
    get_string(M9, UID, M10),
    get_string(M10, GID, M11),
    get_string(M11, MUID, MR),
    STAT := {QID, MODE, ATIME, MTIME, LEN, NAME, UID, GID, MUID}.

% server interface

server(I, O, RQ, TQ) :- 
    read_requests(I, RQ),
    write_replies(TQ, O).

read_requests(I, RQ) :-
    io:read_byte_stream(I, IS),
    read_requests2(IS, RQ).

read_requests2([], RQ) :- RQ := [].
read_requests2(S, RQ) :-
    otherwise |
    get_header(S, SZ, TYPE, TAG, S2),
    PS is SZ - 7,
    list:cut(PS, S2, [], MSG, S3),
    parse_request(TYPE, TAG, MSG, REQ),
    RQ := [REQ|RQ1],
    read_requests2(S3, RQ1).

parse_request(100, TAG, MSG, R):-        % Tversion
    get_int32(MSG, MSIZE, M1),
    get_string(M1, V, _),
    R := version(TAG, MSIZE, V).
parse_request(104, TAG, MSG, R):-        % Tattach
    get_int32(MSG, FID, M1),
    get_int32(M1, AFID, M2),
    get_string(M2, UNAME, M3),
    get_string(M3, ANAME, _),
    R := attach(TAG, FID, AFID, UNAME, ANAME).
parse_request(102, TAG, MSG, R):-        % Tauth
    get_int32(MSG, AFID, M1),
    get_string(M1, UNAME, M2),
    get_string(M2, ANAME, _),
    R := auth(TAG, AFID, UNAME, ANAME).
parse_request(120, TAG, MSG, R):-        % Tclunk
    get_int32(MSG, FID, _),
    R := clunk(TAG, FID).
parse_request(108, TAG, MSG, R):-        % Tflush
    get_int32(MSG, OTAG, _),
    R := flush(TAG, OTAG).
parse_request(112, TAG, MSG, R):-        % Topen
    get_int32(MSG, FID, M1),
    get_mode(M1, MODE, _),
    R := open(TAG, FID, MODE).
parse_request(114, TAG, MSG, R):-        % Tcreate
    get_int32(MSG, FID, M1),
    get_string(M1, NAME, M2),
    get_int32(M2, PERM, M3),
    get_mode(M3, MODE, _),
    R := create(TAG, FID, NAME, PERM, MODE).
parse_request(116, TAG, MSG, R):-        % Tread
    get_int32(MSG, FID, M1),
    get_int64(M1, OFF, M2),
    get_int32(M2, CNT, _),
    R := read(TAG, FID, OFF, CNT).
parse_request(118, TAG, MSG, R):-        % Twrite
    get_int32(MSG, FID, M1),
    get_int64(M1, OFF, M2),
    get_int32(M2, _, M3),
    R := write(TAG, FID, OFF, M3).
parse_request(122, TAG, MSG, R):-        % Tremove
    get_int32(MSG, FID, _),
    R := remove(TAG, FID).
parse_request(124, TAG, MSG, R):-        % Tstat
    get_int32(MSG, FID, _),
    R := stat(TAG, FID).
parse_request(126, TAG, MSG, R):-        % Twstat
    get_int32(MSG, FID, M1),
    get_int16(M1, _, M2),
    parse_stat(M2, STAT, _),
    R := wstat(TAG, FID, STAT).
parse_request(110, TAG, MSG, R):-        % Twalk
    get_int32(MSG, FID, M1),
    get_int32(M1, NFID, M2),
    get_int16(M2, N, M3),
    get_strings(N, M3, NAMES, _),
    R := walk(TAG, FID, NFID, NAMES).
parse_request(TYPE, TAG, MSG, R):-
    otherwise | R := invalid_request(TAG, TYPE, MSG).

get_mode([M|R], MODE, M2) :- M2 := R, MODE := M.

write_replies([], _).
write_replies([R|TQ], O) :- write_reply(R, TQ, O).

write_replies([], TQ, O) :- write_replies(TQ, O).

write_reply(version(TAG, MSIZE, V), TQ, O) :-
    put_int32(MSIZE, M, M2),
    put_string(V, M2, []),
    write_reply_msg(M, 101, TAG, TQ, O).
write_reply(auth(TAG, QID), TQ, O) :-
    put_qid(QID, M, []),
    write_reply_msg(M, 103, TAG, TQ, O).
write_reply(attach(TAG, QID), TQ, O) :-
    put_qid(QID, M, []),
    write_reply_msg(M, 105, TAG, TQ, O).
write_reply(clunk(TAG), TQ, O) :-
    write_reply_msg([], 121, TAG, TQ, O).
write_reply(error(TAG, MSG), TQ, O) :-
    put_string(MSG, M, []),
    write_reply_msg(M, 107, TAG, TQ, O).
write_reply(flush(TAG), TQ, O) :-
    write_reply_msg([], 109, TAG, TQ, O).
write_reply(open(TAG, QID, IOUNIT), TQ, O) :-
    put_qid(QID, M, M1),
    put_int32(IOUNIT, M1, []),
    write_reply_msg(M, 113, TAG, TQ, O).
write_reply(create(TAG, QID, IOUNIT), TQ, O) :-
    put_qid(QID, M, M1),
    put_int32(IOUNIT, M1, []),
    write_reply_msg(M, 115, TAG, TQ, O).
write_reply(read(TAG, DATA), TQ, O) :-
    length(DATA, CNT),
    put_int32(CNT, M, DATA),
    write_reply_msg(M, 117, TAG, TQ, O).
write_reply(write(TAG, CNT), TQ, O) :-
    put_int32(CNT, M, []),
    write_reply_msg(M, 119, TAG, TQ, O).
write_reply(remove(TAG), TQ, O) :-
    write_reply_msg([], 123, TAG, TQ, O).
write_reply(stat(TAG, STAT), TQ, O) :-
    build_stat(STAT, BYTES),
    length(BYTES, N),
    put_int16(N, M, BYTES),
    write_reply_msg(M, 125, TAG, TQ, O).
write_reply(wstat(TAG), TQ, O) :-
    write_reply_msg([], 127, TAG, TQ, O).
write_reply(walk(TAG, QIDS), TQ, O) :-
    length(QIDS, N),
    put_int16(N, M, M1),
    put_nqids(N, QIDS, M1, []),
    write_reply_msg(M, 111, TAG, TQ, O).

put_nqids(0, _, R, TL) :- R := TL.
put_nqids(N, [Q|QIDS], R, TL) :-
    N > 0 | 
    put_qid(Q, R, R2),
    N2 is N - 1,
    put_nqids(N2, QIDS, R2, TL).

write_reply_msg(MSG, TYPE, TAG, TQ, O) :-
    msg_size(MSG, SZ),
    put_header(SZ, TYPE, TAG, M, MSG),
    write_bytes(O, M, OK),
    write_replies(OK, TQ, O).
