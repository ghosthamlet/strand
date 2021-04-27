% 9p test server

-exports([main/0]).

main :-
    o9p:root([d, perm(drwxrwxrwx)], ROOT),
    o9p:static_file(file, [perm('rw-rw-rw-')], "this is a test.\n", 
        ROOT, F1),
    o9p:directory(info, [d, perm(drwxrwxrwx)], ROOT, DIR),
    stats_file(stats, DIR, F2),
    '$log'(files(ROOT, DIR, F1, F2)),
    start(F1, F2, ROOT).

start(F1, F2, ROOT) :- data(F1), data(F2) | o9p:start(ROOT).

stats_file(NAME, DIR, SELF) :-
    o9p:file([name(NAME), perm('r--r--r--')], DIR, SELF, SUPER, S),
    stats_file(S, SELF, SUPER, DIR).

stats_file([], _, _, _).
stats_file([stat(STAT)|S], SELF, SUPER, DIR) :-
    send(SUPER, stat(STAT)),
    stats_file(S, SELF, SUPER, DIR).
stats_file([open(0, OP)|S], SELF, SUPER, DIR) :-
    make_data(DATA),
    o9p:data_source(DATA, SELF, OP),
    stats_file(S, SELF, SUPER, DIR).
stats_file([remove|S], SELF, SUPER, DIR) :-
    o9p:file_remove(SELF, DIR),
    stats_file(S, SELF, SUPER, DIR).
stats_file([X|S], SELF, SUPER, DIR) :-
    otherwise |
    send(SUPER, X),
    stats_file(S, SELF, SUPER, DIR).

make_data(DATA) :-
    '$statistics'(INFO),
    tuple_to_list(INFO, INFO2, []),
    format_stats(INFO2, DATA).

format_stats([], O) :- O := [].
format_stats([X|L], O) :-
    fmt:format_chars("~q\n", [X], O, TL),
    format_stats(L, TL).
