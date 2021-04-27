% Strand compiler - main compiler code

-exports([init_state/5, compile_forms/3]).

compile_forms(FORMS, STATE, DONE) :-
    declarations(FORMS, CLAUSES, STATE, MetaInfo, S2),
    var_tag(S2, VT),
    group([('$META'('$VAR'(VT, 0, 'R')) :- '$VAR'(VT, 0, 'R') := MetaInfo)|CLAUSES], 
        PDEFS, S2, S3),
    check_dups(PDEFS, S3, S4),
    check_exports(PDEFS, S4, S5),
    output_file(S5, ONAME),
    open_file(ONAME, w, OUT),
    compile_module(PDEFS, S5, PCODE),
    write_module(PCODE, [], OUT, DONE).

% state: {INAME, ONAME, EXPORTS, VARTAG, ERRSTREAM]
%   EXPORTS = all | [N/A, ...]
init_state(IN, ON, S, VT, E) :- 
    rnd:pseudo_random_integer(VT1, _),
    VT is abs(VT1) \\ 100000, 
    S := {IN, ON, all, VT, E}.

% state accessors

output_file({_, ON, _, _, _}, R) :- R := ON.
exports({_, _, EXP, _, _}, R) :- R := EXP.
var_tag({_, _, _, VT, _}, R) :- R := VT.
errors({_, _, _, _, E}, R) :- R := E.

emit_diagnostic(MSG, {IN, ON, XL, VT, E}, S) :-
    E := [MSG|E2],
    S := {IN, ON, XL, VT, E2}.

add_export(NA, {IN, ON, all, VT, E}, S) :- 
    S := {IN, ON, [NA, '$META'/1], VT, E}.
add_export(NA, {IN, ON, XL, VT, E}, S) :- 
    S := {IN, ON, [NA|XL], VT, E}.

close_errors({_, _, _, _, E}) :- E := [].

% declaration processing

declarations([], CS, S1, MetaInfo, S) :- 
    CS := [], S := S1, MetaInfo := [].
declarations([-DECL|R], CS, S1, MetaInfo, S) :-
    declaration(DECL, S1, MetaInfo, S2, MetaInfo2),
    declarations(R, CS, S2, MetaInfo2, S).
declarations([C|R], CS, S1, MetaInfo, S) :- 
    otherwise | 
    CS := [C|CS2], 
    declarations(R, CS2, S1, MetaInfo, S).

declaration(exports(LST), S1, MetaInfo1, S, MetaInfo) :- 
    add_exports(LST, S1, S),    
    MetaInfo1 := MetaInfo.
declaration(meta(Info), S1, MetaInfo1, S, MetaInfo) :-
    MetaInfo1 := [Info|MetaInfo],
    S := S1.
declaration(machine(VMType), S1, MetaInfo1, S, MetaInfo) :-
    MetaInfo1 := [machine(VMType)|MetaInfo],
    S := S1.
declaration(DECL, S1, MetaInfo1, S, MetaInfo) :-
    otherwise |
    MetaInfo1 := MetaInfo,
    compile_error('invalid declaration: ~q\n', [DECL], S1, S).

add_exports([], S1, S) :- S := S1.
add_exports([N/A|R], S1, S) :-
    add_export(N/A, S1, S2),
    add_exports(R, S2, S).
add_exports([X|_], S1, S) :-
    otherwise |
    compile_error('invalid export specification: ~q~n', [X], S1, S).

% various checks

check_dups([], S1, S) :- S := S1.
check_dups([{N, A, _}|PDEFS], S1, S) :-
    check_dups(PDEFS, N, A, S1, S2),
    check_dups(PDEFS, S2, S).

check_dups([], _, _, S1, S) :- S := S1.
check_dups([{N, A, _}|_], N, A, S1, S) :-
    compile_error('discontiguous process definition: ~a/~d\n', [N, A], S1, S).
check_dups([_|PDEFS], N, A, S1, S) :-
    otherwise | 
    check_dups(PDEFS, N, A, S1, S).

check_exports(PDEFS, S1, S) :-
    exports(S1, XL),
    check_exports1(XL, PDEFS, S1, S).

check_exports1(all, _, S1, S) :- S := S1.
check_exports1([], _, S1, S) :- S := S1.
check_exports1([N/A|XL], PDEFS, S1, S) :-
    check_exports2(PDEFS, N, A, S1, S2),
    check_exports1(XL, PDEFS, S2, S).

check_exports2([], N, A, S1, S) :-
    compile_error('exported process is not defined: ~a/~d\n', [N, A], S1, S).
check_exports2([{N, A, _}|_], N, A, S1, S) :-
    S := S1.
check_exports2([_|PDEFS], N, A, S1, S) :-
    otherwise | 
    check_exports2(PDEFS, N, A, S1, S).

check_definition(NA, G, S1, S) :-
    internal(NA, K),
    check_definition2(K, NA, G, S1, S).

check_definition2(user, _, _, S1, S) :- S := S1.
check_definition2(none, NA, G, S1, S) :- 
    special(NA, F),
    check_definition2(F, NA, G, S1, S).
check_definition2(K, N/A, [Def|_], S1, S) :-
    K =\= none, K =\= user |
    compile_error('redefinition of primitive process ~s/~d: ~q\n', [N, A, Def], S1, S).

check_singletons([], _, _, S1, S) :- S := S1.
check_singletons([I|SS], VS, T, S1, S) :-
    check_singletons2(VS, I, T, S1, S2),
    check_singletons(SS, VS, T, S2, S).

check_singletons2([], _, _, S1, S) :- S := S1.
check_singletons2([{I, N}|_], I, T, S1, S) :-
    N =\= '_' |
    head(T, DN, A, S1, S2),
    compile_warning('warning: singleton variable in definition of ~a/~d: ~a\n', 
        [DN, A, N], S2, S).
check_singletons2([_|VS], I, T, S1, S) :-
    otherwise | check_singletons2(VS, I, T, S1, S).

% write module to file
write_module([], _, _, DONE) :- DONE := [].
write_module([CODE|R], [], OUT, DONE) :-
    write_bytes(OUT, CODE, DONE1), 
    write_module(R, DONE1, OUT, DONE).

% flatten collected code fragments into byte list

flatten_code(CODE, CLIST) :- 
    flatten_code(CODE, CLIST, []).

flatten_code([], C, T) :- C := T.
flatten_code([X|R], C, T) :-
    flatten_code1(X, C, T1),
    flatten_code(R, T1, T).

flatten_code1(X, C, T) :- 
    integer(X) | integer_to_list(X, 10, C, T).
flatten_code1(X, C, T) :-
    string(X) | string_to_byte_list(X, C, T).
flatten_code1(X, C, T) :-
    bytes(X) | bytes_to_list(X, C, T).
flatten_code1(X, _, _) :-
    otherwise | error(internal_compiler_error('bad code expression', X)).

% toplevel

compile_module(PDEFS, S, SCODE) :-
    gen_mprefix(PDEFS, PCODE),
    SCODE := [PCODE|STAIL],
    compile_module2(PDEFS, 0, PDEFS, S, STAIL).

compile_module2([], _, _, S, SCODE) :- 
    SCODE := [],
    close_errors(S).
compile_module2([{N, A, G}|R], I, PDEFS, S, SCODE) :-
    compile_group(G, N, A, I, PDEFS, S, S2, SCODE, STAIL),
    I2 is I + 1,
    compile_module2(R, I2, PDEFS, S2, STAIL).

gen_mprefix(PDEFS, SCODE) :-
    length(PDEFS, N),
    N2 is N * 2,
    CODE1 := ['T', N2, ':'],
    flatten_code(CODE1, SCODE).

% compile group of process definitions 

compile_group([C], N, A, I, PDEFS, S1, S, SCODE, STAIL) :-
    var_tag(S1, VT),
    term:simple_clause(C, VT, Simple),
    compile_group2(Simple, C, N, A, I, PDEFS, S1, S, SCODE, STAIL).
compile_group(G, N, A, I, PDEFS, S1, S, SCODE, STAIL) :-
    otherwise |
    compile_group3(G, N, A, I, PDEFS, S1, S, SCODE, STAIL).

compile_group2(no, C, N, A, I, PDEFS, S1, S, SCODE, STAIL) :-
    compile_group3([C], N, A, I, PDEFS, S1, S, SCODE, STAIL).
compile_group2(VIs, C, N, A, I, PDEFS, S1, S, SCODE, STAIL) :-
    VIs =\= no |
    exports(S1, XL),
    var_tag(S1, VTAG),
    check_definition(N/A, [C], S1, S2),
    gen_entry(N, A, CODE, ['['|CODE1]),
    classify_variables(C, VTAG, VS, SS, S2, S3),
    clause_parts(C, _, B),
    compile_simple_head(VIs, VS, CODE1, ['p'|TAIL1]),
    compile_tail(B, VS, SS, VIs, S3, S, PDEFS, TAIL1, [']\n']),
    finalize_code(XL, N, A, I, CODE, SCODE, STAIL).

compile_group3(G, N, A, I, PDEFS, S1, S, SCODE, STAIL) :-
    exports(S1, XL),
    var_tag(S1, VTAG),
    check_definition(N/A, G, S1, S2),
    gen_entry(N, A, CODE, CODE1),
    integer(A, CODE1, ['A'|CODE2]),
    indexing_groups(G, VTAG, TL, LL, AL, OL),
    compile_pdef(G, PDEFS, S2, S, [TL, LL, AL, OL], CODE2),
    finalize_code(XL, N, A, I, CODE, SCODE, STAIL).

finalize_code(XL, N, A, I, CODE, SCODE, STAIL) :-
    flatten_code(CODE, STR),
    length(STR, CLEN),
    LEN is CLEN - 1,    % subtract trailing newline
    compile_prefix(XL, N, A, I, LEN, PREF),
    SCODE := [PREF, STR|STAIL].

gen_entry(N, A, CODE, TAIL) :-
    byte_length(N, NLEN), 
    integer_to_list(A, AL), 
    length(AL, ALEN),
    LEN is NLEN + ALEN + 1,
    CODE := ['D', LEN, ':', N, '/', A|TAIL].

compile_prefix([], _, _, I, CLEN, PREF) :-
    internal_prefix(I, CLEN, PREF).
compile_prefix(all, N, A, _, CLEN, PREF) :-
    exported_prefix(N, A, CLEN, PREF).
compile_prefix([N/A|_], N, A, _, CLEN, PREF) :-
    exported_prefix(N, A, CLEN, PREF).
compile_prefix([_|R], N, A, I, CLEN, PREF) :-
    otherwise | 
    compile_prefix(R, N, A, I, CLEN, PREF).

internal_prefix(I, CLEN, PREF) :-
    CODE := ['I', I, ':$', CLEN, ':'],      % unexported
    flatten_code(CODE, PREF).

exported_prefix(N, A, CLEN, PREF) :-
    byte_length(N, NLEN),       % exported
    CODE := ['T2:$', NLEN, ':', N|CODE1],
    integer(A, CODE1, ['$', CLEN, ':']),
    flatten_code(CODE, PREF).

compile_pdef(G, PDEFS, S1, S, [[], [], [], _], CODE) :-
    compile_pdef1(G, PDEFS, '[', S1, S, CODE, TAIL),
    TAIL := [']\n'].
compile_pdef(_, PDEFS, S1, S, SL, CODE) :-
    otherwise | 
    CODE := ['[Ss'|TAIL1],
    compile_switch_pdef(SL, ['St', 'Sl', 'Sa', 'So'], PDEFS, S1, S, TAIL1).

compile_pdef1([], _, _, S1, S, CODE, TAIL) :- 
    CODE := TAIL, S := S1.
compile_pdef1([T|G], PDEFS, TRY, S1, S, CODE, TAIL) :-
    CODE := [TRY|TAIL1],
    var_tag(S1, VTAG),
    classify_variables(T, VTAG, VS, SS, S1, S2),    
    compile_term(T, VS, SS, PDEFS, S2, S3, TAIL1, TAIL2),
    compile_pdef1(G, PDEFS, '\'', S3, S, TAIL2, TAIL).

% clause indexing

% less than 4 non-"other" clauses disables indexing
indexing_groups(CLS, VTAG, TL, LL, AL, OL) :-
    term:classify_arg(CLS, VTAG, TL1, LL1, AL1, OL1),
    length(TL1, TLEN),
    length(LL1, LLEN),
    length(AL1, ALEN),
    T is TLEN + LLEN + ALEN,
    indexing_groups(T, TL1, LL1, AL1, OL1, TL, LL, AL, OL).

indexing_groups(T, TL1, LL1, AL1, OL1, TL, LL, AL, OL) :-
    T > 3 | TL := TL1, LL := LL1, AL := AL1, OL := OL1.
indexing_groups(T, TL1, LL1, AL1, OL1, TL, LL, AL, OL) :-
    T =< 3 |
    TL := [], LL := [], AL := [],
    list:append([TL1, LL1, AL1, OL1], OL).

compile_switch_pdef([], _, _, S1, S, CODE) :- 
    CODE := [']\n'], S := S1.
compile_switch_pdef([[]], ['So'], _, S1, S, CODE) :-
    % in case of no "other" set - patch up `switch` op anyway
    CODE := ['So]\n'], S := S1.
compile_switch_pdef([[]|RG], [_|SR], PDEFS, S1, S, CODE) :-
    compile_switch_pdef(RG, SR, PDEFS, S1, S, CODE).
compile_switch_pdef([[C]|RG], [SOP|SR], PDEFS, S1, S, CODE) :-
    SOP =\= 'So' |
    CODE := [SOP, '0:'|TAIL1],
    compile_pdef1([C], PDEFS, '', S1, S2, TAIL1, TAIL2),
    compile_switch_pdef(RG, SR, PDEFS, S2, S, TAIL2).
compile_switch_pdef([G|RG], ['Sa'|SR], PDEFS, S1, S, CODE) :-
    G =\= [] |
    length(G, GA),
    CODE := ['Sa', GA, ':'|TAIL1],
    compile_switch_atom(G, PDEFS, '', S1, S2, TAIL1, TAIL2),
    compile_switch_pdef(RG, SR, PDEFS, S2, S, TAIL2).
compile_switch_pdef([G|RG], ['St'|SR], PDEFS, S1, S, CODE) :-
    G =\= [] |
    partition_tuples(G, GOOD, BAD),
    length(GOOD, GT),
    CODE := ['St', GT, ':'|TAIL1],
    compile_switch_tuple(BAD, GOOD, PDEFS, '', S1, S2, TAIL1, TAIL2),
    compile_switch_pdef(RG, SR, PDEFS, S2, S, TAIL2).
compile_switch_pdef([G|RG], ['Sl'|SR], PDEFS, S1, S, CODE) :-
    G =\= [] |
    partition_heads(G, GOOD, BAD),
    length(GOOD, GL),
    CODE := ['Sl', GL, ':'|TAIL1],
    compile_switch_tuple(BAD, GOOD, PDEFS, '', S1, S2, TAIL1, TAIL2),
    compile_switch_pdef(RG, SR, PDEFS, S2, S, TAIL2).
compile_switch_pdef([G|RG], [SOP|SR], PDEFS, S1, S, CODE) :-
    G =\= [] |
    CODE := [SOP|TAIL1],
    compile_pdef1(G, PDEFS, '\'', S1, S2, TAIL1, TAIL2),
    compile_switch_pdef(RG, SR, PDEFS, S2, S, TAIL2).

compile_switch_atom([], _, _, S1, S, CODE, TAIL) :-
    CODE := ['Z'|TAIL], S := S1.
compile_switch_atom([T|G], PDEFS, TRY, S1, S, CODE, TAIL) :-
    first_argument(T, ARG),
    CODE := [TRY|CODE1],
    encode_switch_label(ARG, CODE1, ['0'|TAIL1]),
    var_tag(S1, VTAG),
    classify_variables(T, VTAG, VS, SS, S1, S2),
    compile_term(T, VS, SS, PDEFS, S2, S3, TAIL1, TAIL2),
    compile_switch_atom(G, PDEFS, '\'', S3, S, TAIL2, TAIL).    

encode_switch_label([], CODE, TAIL) :-
    CODE := ['@$2:[]'|TAIL].
encode_switch_label(STR, CODE, TAIL) :-
    string(STR) | 
    length(STR, LEN),
    CODE := ['@$', LEN, ':', STR|TAIL].
encode_switch_label(INT, CODE, TAIL) :-
    integer(INT) |
    CODE := ['@'|CODE1], 
    integer(INT, CODE1, TAIL).

first_argument(T, ARG) :-
    term:args(T, ARGS), first_argument2(ARGS, ARG).

first_argument2([X|_], ARG) :- ARG := X.

partition_tuples([], GOOD, BAD) :-
    GOOD := [], BAD := [].
partition_tuples([T|G], GOOD, BAD) :-
    first_argument(T, ARG),
    partition_tuples(ARG, T, G, GOOD, BAD).

partition_tuples({}, T, G, GOOD, BAD) :-
    BAD := [T|BAD1], 
    partition_tuples(G, GOOD, BAD1).
partition_tuples(X, T, G, GOOD, BAD) :-
    X =\= {} |
    get_arg(1, X, A),
    length(X, TL),
    partition_tuples1(A, TL, T, G, GOOD, BAD).

partition_tuples1([], TL, T, G, GOOD, BAD) :-
    GOOD := [{[], TL, T}|GOOD1],
    partition_tuples(G, GOOD1, BAD).
partition_tuples1(A, TL, T, G, GOOD, BAD) :-
    string(A) |
    GOOD := [{A, TL, T}|GOOD1],
    partition_tuples(G, GOOD1, BAD).
partition_tuples1(A, TL, T, G, GOOD, BAD) :-
    integer(A) |
    GOOD := [{A, TL, T}|GOOD1],
    partition_tuples(G, GOOD1, BAD).
partition_tuples1(_, _, T, G, GOOD, BAD) :-
    otherwise |
    BAD := [T|BAD1], 
    partition_tuples(G, GOOD, BAD1).

compile_switch_tuple([], [], _, _, S1, S, CODE, TAIL) :-
    S := S1, CODE := TAIL.
compile_switch_tuple([], [{N, A, T}|GOOD], PDEFS, TRY, S1, S, CODE, TAIL) :-
    CODE := [TRY|TAIL0],
    encode_switch_label(N, TAIL0, TAIL1),
    integer(A, TAIL1, TAIL2),
    var_tag(S1, VTAG),
    classify_variables(T, VTAG, VS, SS, S1, S2),
    compile_term(T, VS, SS, PDEFS, S2, S3, TAIL2, TAIL3),
    compile_switch_tuple([], GOOD, PDEFS, '\'', S3, S, TAIL3, TAIL).    
compile_switch_tuple([T|BAD], GOOD, PDEFS, TRY, S1, S, CODE, TAIL) :-
    CODE := [TRY|TAIL1],
    var_tag(S1, VTAG),
    classify_variables(T, VTAG, VS, SS, S1, S2),
    compile_term(T, VS, SS, PDEFS, S2, S3, TAIL1, TAIL2),
    compile_switch_tuple(BAD, GOOD, PDEFS, '\'', S3, S, TAIL2, TAIL). 

partition_heads([], GOOD, BAD) :-
    GOOD := [], BAD := [].
partition_heads([T|G], GOOD, BAD) :-
    first_argument(T, ARG),
    partition_heads(ARG, T, G, GOOD, BAD).

partition_heads([X|_], T, G, GOOD, BAD) :-
    tuple(X), X =\= {} |
    get_arg(1, X, A),
    length(X, TL),
    partition_heads1(A, TL, T, G, GOOD, BAD).
partition_heads([X|_], T, G, GOOD, BAD) :-
    string(X) |
    GOOD := [{X, 0, T}|GOOD1],
    partition_heads(G, GOOD1, BAD).
partition_heads([X|_], T, G, GOOD, BAD) :-
    integer(X) |
    GOOD := [{X, 0, T}|GOOD1],
    partition_heads(G, GOOD1, BAD).
partition_heads(_, T, G, GOOD, BAD) :-
    BAD := [T|BAD1], 
    partition_heads(G, GOOD, BAD1).

partition_heads1([], TL, T, G, GOOD, BAD) :-
    GOOD := [{[], TL, T}|GOOD1],
    partition_heads(G, GOOD1, BAD).
partition_heads1(A, TL, T, G, GOOD, BAD) :-
    string(A) |
    GOOD := [{A, TL, T}|GOOD1],
    partition_heads(G, GOOD1, BAD).
partition_heads1(A, TL, T, G, GOOD, BAD) :-
    integer(A) |
    GOOD := [{A, TL, T}|GOOD1],
    partition_heads(G, GOOD1, BAD).
partition_heads1(_, _, T, G, GOOD, BAD) :-
    otherwise |
    BAD := [T|BAD1], 
    partition_heads(G, GOOD, BAD1).

% separate singleton from non-singleton variables

classify_variables(T, VTAG, VS, SS, S1, S) :-
    term:vars(T, VTAG, VS1),
    var_indices(VS1, VIS),
    sort:sort(VIS, VS),
    list:unique(VS, VIS, SS),
    check_singletons(SS, VS1, T, S1, S).

var_indices([], IS) :- IS := [].
var_indices([{I, _}|VS], IS) :- IS := [I|IS2], var_indices(VS, IS2).

% compile single process definition

compile_term((H :- T), VS, SS, PDEFS, S1, S, CODE, TAIL) :-
    compile_term1(H, T, VS, SS, PDEFS, S1, S, CODE, TAIL).
compile_term(H, VS, SS, PDEFS, S1, S, CODE, TAIL) :-
    compile_term1(H, true, VS, SS, PDEFS, S1, S, CODE, TAIL).

compile_term1(H, T, VS, SS, PDEFS, S1, S, CODE, TAIL) :-
    term:args(H, ARGS),
    compile_head(ARGS, VS, SS, VSS, S1, S2, CODE, TAIL1),
    compile_tail(T, VS, SS, VSS, S2, S, PDEFS, TAIL1, TAIL).

compile_head(ARGS, VS, SS, VSS, S1, S, CODE, TAIL) :-
    length(VS, ESIZE),
    compile_head1(ESIZE, ARGS, SS, VSS, S1, S, CODE, TAIL).

compile_head1(0, ARGS, SS, VSS, S1, S, CODE, TAIL) :-
    compile_head_arguments(ARGS, 0, SS, [], VSS, S1, S, CODE, TAIL).
compile_head1(N, ARGS, SS, VSS, S1, S, CODE, TAIL) :-
    N > 0 | 
    integer(N, CODE, ['V'|TAIL1]),
    compile_head_arguments(ARGS, 0, SS, [], VSS, S1, S, TAIL1, TAIL).

compile_simple_head(Args, VS, CODE, TAIL) :-
    length(VS, Len),
    integer(Len, CODE, ['V'|TAIL1]),
    compile_simple_head2(Args, TAIL1, TAIL).

compile_simple_head2([], CODE, TAIL) :- CODE := TAIL.
compile_simple_head2([VI|Vars], CODE, TAIL) :-
    CODE := ['P', VI, ':'|TAIL1],
    compile_simple_head2(Vars, TAIL1, TAIL).

compile_head_arguments([], _, _, VSS, VSS2, S1, S, CODE, TAIL) :- 
    CODE := TAIL, VSS2 := VSS, S := S1.
compile_head_arguments([X|R], I, SS, VSS, VSS2, S1, S, CODE, TAIL) :-
    CODE := ['G', I, ':'|TAIL1],
    var_tag(S1, VTAG), 
    compile_match(X, VTAG, SS, VSS, VSS1, S1, S2, TAIL1, TAIL2),
    I2 is I + 1,
    compile_head_arguments(R, I2, SS, VSS1, VSS2, S2, S, TAIL2, 
        TAIL).

% compile head matching

compile_match('$VAR'(TAG, VI, _), TAG, SS, VSS, VSS2, S1, S, CODE, TAIL) :-
    S := S1,
    compile_match_var(SS, VI, VSS, VSS2, CODE, TAIL).
compile_match(T, VTAG, SS, VSS, VSS2, S1, S, CODE, TAIL) :-
    tuple(T) |
    length(T, TLEN),
    integer(TLEN, CODE, ['N'|TAIL1]),
    tuple_to_list(T, TL, []),
    compile_tuple_match(TL, VTAG, SS, VSS, VSS2, S1, S, TAIL1, TAIL).
compile_match([], _, _, VSS, VSS2, S1, S, CODE, TAIL) :-
    CODE := ['%'|TAIL], VSS2 := VSS, S := S1.
compile_match(X, _, _, VSS, VSS2, S1, S, CODE, TAIL) :-
    integer(X) | 
    integer(X, CODE, ['U'|TAIL]), 
    VSS2 := VSS, S := S1.
compile_match(X, _, _, VSS, VSS2, S1, S, CODE, TAIL) :-
    bytes(X) | 
    byte_length(X, Len),
    bytes_to_list(X, Bytes, []),
    CODE := ['R'|TAIL1],
    integer_list([Len|Bytes], TAIL1, TAIL),
    VSS2 := VSS, S := S1.
compile_match(X, _, _, VSS, VSS2, S1, S, CODE, TAIL) :-
    string(X) | 
    byte_length(X, LEN),
    CODE := ['$', LEN, ':', X, 'g='|TAIL], VSS2 := VSS, S := S1.
compile_match([X|Y], VTAG, SS, VSS, VSS2, S1, S, CODE, TAIL) :-
    CODE := ['L'|TAIL1],
    compile_match(X, VTAG, SS, VSS, VSS1, S1, S2, TAIL1, TAIL2),
    compile_match(Y, VTAG, SS, VSS1, VSS2, S2, S, TAIL2, TAIL).
compile_match(X, _, _, _, VSS2, S1, S, CODE, TAIL) :-
    otherwise | 
    VSS2 := [], CODE := TAIL,
    compile_error('invalid match value: ~q~n', [X], S1, S).

compile_match_var([], VI, VSS, VSS2, CODE, TAIL) :-
    compile_match_var1(VSS, VI, VSS, VSS2, CODE, TAIL).
compile_match_var([VI|_], VI, VSS, VSS2, CODE, TAIL) :-
    CODE := ['O'|TAIL], VSS2 := VSS. % singleton
compile_match_var([_|R], VI, VSS, VSS2, CODE, TAIL) :-
    otherwise | 
    compile_match_var(R, VI, VSS, VSS2, CODE, TAIL).

compile_match_var1([], VI, VSS, VSS2, CODE, TAIL) :-
    CODE := ['P', VI, ':'|TAIL], VSS2 := [VI|VSS]. % first occurrence
compile_match_var1([VI|_], VI, VSS, VSS2, CODE, TAIL) :-
    integer(VI, CODE, ['M'|TAIL]), VSS2 := VSS.  % subseq. occurrence
compile_match_var1([_|R], VI, VSS, VSS2, CODE, TAIL) :-
    otherwise | 
    compile_match_var1(R, VI, VSS, VSS2, CODE, TAIL).

compile_tuple_match([], _, _, VSS, VSS2, S1, S, CODE, TAIL) :-
    VSS2 := VSS, CODE := TAIL, S := S1.
compile_tuple_match([X|R], VTAG, SS, VSS, VSS2, S1, S, CODE, TAIL) :-
    compile_match(X, VTAG, SS, VSS, VSS1, S1, S2, CODE, TAIL1),
    compile_tuple_match(R, VTAG, SS, VSS1, VSS2, S2, S, TAIL1, TAIL).

compile_tail((G | B), VS, SS, VSS, S1, S, PDEFS, CODE, TAIL) :-
    set:difference(VS, VSS, SSG),
    compile_guards(G, SSG, S1, S2, CODE, TAIL1),
    compile_body(B, VS, SS, VSS, S2, S, PDEFS, TAIL1, TAIL).
compile_tail(B, VS, SS, VSS, S1, S, PDEFS, CODE, TAIL) :-
    otherwise | 
    compile_body(B, VS, SS, VSS, S1, S, PDEFS, CODE, TAIL).

% compile guards

compile_guards((G1, G2), SS, S1, S, CODE, TAIL) :-
    compile_guard(G1, SS, S1, S2, CODE, TAIL1),
    compile_guards(G2, SS, S2, S, TAIL1, TAIL).
compile_guards(G, SS, S1, S, CODE, TAIL) :-
    otherwise | 
    compile_guard(G, SS, S1, S, CODE, TAIL).

compile_guard(otherwise, _, S1, S, CODE, TAIL) :- 
    CODE := TAIL, S := S1.
compile_guard(X, SS, S1, S, CODE, TAIL) :-
    tuple(X) |
    tuple_to_list(X, XL, []),
    list:pair(XL, N, ARGS),
    length(ARGS, A),
    guard(N/A, K),
    compile_guard1(K, X, ARGS, SS, S1, S, CODE, TAIL).
compile_guard(X, SS, S1, S, CODE, TAIL) :-
    string(X) | 
    guard(X/0, K),
    compile_guard1(K, X, [], SS, S1, S, CODE, TAIL).
compile_guard(X, _, S1, S, CODE, TAIL) :-
    otherwise |
    CODE := TAIL, 
    compile_error('invalid guard expression: ~q\n', [X], S1, S).

compile_guard1(none, X, _, _, S1, S, CODE, TAIL) :-
    CODE := TAIL,
    compile_error('invalid guard: ~q~n', [X], S1, S).
compile_guard1(K/n, X, ARGS, SS, S1, S, CODE, TAIL) :- 
    var_tag(S1, VT),
    compile_expressions(ARGS, VT, SS, X, S1, S, CODE, ['g', K|TAIL]).
compile_guard1(K, _, ARGS, SS, S1, S, CODE, TAIL) :- 
    otherwise |
    compile_values(ARGS, SS, S1, S, CODE, ['g', K|TAIL]).

% compile term arguments

compile_values([], _, S1, S, CODE, TAIL) :- 
    CODE := TAIL, S := S1.
compile_values([X|R], SS, S1, S, CODE, TAIL) :-
    var_tag(S1, VTAG),
    compile_value(X, VTAG, SS, S1, S2, CODE, TAIL1),
    compile_values(R, SS, S2, S, TAIL1, TAIL).

compile_value('$VAR'(TAG, I, _), TAG, SS, S1, S, CODE, TAIL) :-
    S := S1,
    compile_value_var(SS, I, CODE, TAIL).
compile_value({}, _, _, S1, S, CODE, TAIL) :- 
    CODE := ['0B'|TAIL], S := S1.
compile_value(T, VTAG, SS, S1, S, CODE, TAIL) :-
    tuple(T) | 
    term:constant_term(T, VTAG, CT),
    compile_value_compound(CT, T, VTAG, SS, S1, S, CODE, TAIL).
compile_value(X, _, _, S1, S, CODE, TAIL) :-
    integer(X) | 
    CODE := ['z', X, ':'|TAIL], S := S1.
compile_value(X, _, _, S1, S, CODE, TAIL) :-
    bytes(X) | 
    byte_length(X, Len),
    bytes_to_list(X, Bytes, []),
    CODE := ['T'|TAIL1],
    integer_list([Len|Bytes], TAIL1, TAIL),
    S := S1.
compile_value([], _, _, S1, S, CODE, TAIL) :- 
    CODE := [','|TAIL], S := S1.
compile_value(X, _, _, S1, S, CODE, TAIL) :-
    string(X) | 
    byte_length(X, XLEN),
    CODE := ['$', XLEN, ':', X|TAIL], S := S1.
compile_value(X, VTAG, SS, S1, S, CODE, TAIL) :-
    list(X) |
    term:constant_term(X, VTAG, CT),
    compile_value_compound(CT, X, VTAG, SS, S1, S, CODE, TAIL).
compile_value(X, _, _, S1, S, CODE, TAIL) :-
    otherwise | 
    CODE := TAIL,
    compile_error('invalid value: ~q~n', [X], S1, S).

compile_value_compound(yes, X, _, _,S1, S, CODE, TAIL) :-
    pack(X, PX),
    length(PX, LEN),
    S := S1,
    CODE := ['Y', LEN, ':', PX|TAIL].
compile_value_compound(no, [X|Y], VTAG, SS, S1, S, CODE, TAIL) :-
    compile_value(X, VTAG, SS, S1, S2, CODE, TAIL1),
    compile_value(Y, VTAG, SS, S2, S, TAIL1, ['.'|TAIL]).
compile_value_compound(no, T, _, SS, S1, S, CODE, TAIL) :-
    tuple(T) |
    tuple_to_list(T, TL, []), 
    list:reverse(TL, TL2),
    length(T, TLEN),
    integer(TLEN, CODE1, ['B'|TAIL]),
    compile_values(TL2, SS, S1, S, CODE, CODE1).

compile_value_var([], I, CODE, TAIL) :- 
    CODE := ['E', I, ':'|TAIL].    % non-singleton
compile_value_var([I|_], I, CODE, TAIL) :- 
    CODE := ['?'|TAIL].     % singleton
compile_value_var([_|R], I, CODE, TAIL) :-
    otherwise | 
    compile_value_var(R, I, CODE, TAIL).

% compile body goals

compile_body(B, VS, SS, VSS, S1, S, PDEFS, CODE, TAIL) :-
    set:difference(VS, SS, VS1),
    assign_vars(VS1, VSS, CODE, TAIL1),
    reorder_body(B, FB),
    compile_goals(FB, SS, S1, S, PDEFS, TAIL1, TAIL).

reorder_body(B, BR) :-
    term:flatten_body(B, B1, BTL),
    reorder_body(B1, BTL, BR).

% move first goal to end, meeting user's expectations that goals are
% scheduled roughly in textual order.
reorder_body([G1|B], TL, BR) :-
    BR := B, TL := [G1].

% assign variables that did not occur in clause head
assign_vars([], _, CODE, TAIL) :- CODE := TAIL.
assign_vars([VI|R], VSS, CODE, TAIL) :-
    assign_vars1(VSS, VI, CODE, TAIL1),
    assign_vars(R, VSS, TAIL1, TAIL).

assign_vars1([], VI, CODE, TAIL) :- 
    CODE := ['?P', VI, ':'|TAIL].
assign_vars1([VI|_], VI, CODE, TAIL) :- CODE := TAIL.
assign_vars1([_|R], VI, CODE, TAIL) :-
    otherwise | assign_vars1(R, VI, CODE, TAIL).

compile_goals([true], _, S1, S, _, CODE, TAIL) :-
    CODE := ['X'|TAIL], S := S1.
compile_goals([T], SS, S1, S, PDEFS, CODE, TAIL) :-
    T =\= true |
    CODE := [';'|TAIL1],
    compile_goal(T, SS, S1, S, PDEFS, TAIL1, ['X'|TAIL]).
compile_goals([T|B], SS, S1, S, PDEFS, CODE, TAIL) :-
    T =\= true, B =\= [] |
    CODE := ['('|TAIL1],
    compile_goal(T, SS, S1, S2, PDEFS, TAIL1, ['X)'|TAIL2]),
    compile_goals(B, SS, S2, S, PDEFS, TAIL2, TAIL).

compile_goal(true, _, S1, S, _, CODE, TAIL) :- 
    CODE := TAIL, S := S1.
compile_goal(X := Y, SS, S1, S, _, CODE, TAIL) :-
    var_tag(S1, VTAG), 
    assignment_target(X, VTAG, VI, S1, S2),
    non_circular_assignment(Y, VI, VTAG, S2, S3),
    compile_values([X, Y], SS, S3, S, CODE, ['!'|TAIL]).
compile_goal(X is Y, SS, S1, S, _, CODE, TAIL) :-
    var_tag(S1, VTAG), 
    compile_value(X, VTAG, SS, S1, S2, CODE, TAIL1),
    compile_expression(Y, SS, S2, S, TAIL1, ['#!'|TAIL]).
compile_goal(run(T, ST, C), SS, S1, S, PDEFS, CODE, TAIL) :-
    functor(T, N, A, S1, S2),
    find_pdef(PDEFS, N, A, IX, S2, S3),
    term:args(T, ARGS),
    list_to_tuple(ARGS, ARGV),
    CODE := ['Hz', IX, ':'|TAIL1],
    compile_values([ARGV, ST, C], SS, S3, S, TAIL1, ['K73:'|TAIL]). % $run/5
compile_goal(current_module(M), SS, S1, S, _, CODE, TAIL) :-
    CODE := ['H'|TAIL1],
    compile_values([M], SS, S1, S, TAIL1, ['K11:'|TAIL]).    % $load_module/2
compile_goal(foreach(Var, Lst, Goal), SS, S1, S, PDEFS, CODE, TAIL) :-
    var_tag(S1, Tag),
    compile_foreach(Var, Lst, Goal, Tag, SS, S1, S, PDEFS, CODE, TAIL).
compile_goal(when(Var, Goal), SS, S1, S, PDefs, Code, Tail) :-
    var_tag(S1, Tag),
    compile_when(Var, Goal, Tag, SS, S1, S, PDefs, Code, Tail).
compile_goal(T@NODE, SS, S1, S, PDEFS, CODE, TAIL) :-
    compile_remote_call(T, NODE, SS, S1, S, PDEFS, CODE, TAIL).
compile_goal(MN:CALL, _, S1, S, _, CODE, TAIL) :-
    string(CALL) |
    byte_length(MN, MLEN),
    byte_length(CALL, NLEN),
    S := S1,
    CODE := ['C', MLEN, ':', MN, NLEN, ':', CALL, 0, ':'|TAIL].
compile_goal(MN:CALL, SS, S1, S, _, CODE, TAIL) :-
    tuple(CALL) |
    tuple_to_list(CALL, TL, []),
    list:pair(TL, N, ARGS),
    byte_length(MN, MLEN),
    byte_length(N, NLEN),
    length(ARGS, A),
    compile_values(ARGS, SS, S1, S, CODE, ['C', MLEN, ':', MN, NLEN, 
        ':', N, A, ':'|TAIL]).
compile_goal('$foreign_call'(CALL), SS, S1, S, _, CODE, TAIL) :-
    compile_foreign_call(CALL, SS, S1, S, CODE, TAIL).
compile_goal(CALL, SS, S1, S, PDEFS, CODE, TAIL) :-
    string(CALL), CALL =\= true |
    compile_call(CALL, 0, [], SS, S1, S, PDEFS, CODE, TAIL).
compile_goal(CALL, SS, S1, S, PDEFS, CODE, TAIL) :-
    tuple(CALL) | 
    tuple_to_list(CALL, TL, []),
    list:pair(TL, N, ARGS),
    length(ARGS, A),
    compile_call(N, A, ARGS, SS, S1, S, PDEFS, CODE, TAIL).
compile_goal(X, _, S1, S, _, CODE, TAIL) :-
    otherwise | 
    CODE := TAIL,
    compile_error('invalid term: ~q\n', [X], S1, S).

compile_foreach('$VAR'(Tag, I, _), Lst, Goal, Tag, SS, S1, S, PDefs, Code, Tail) :-
    Goal =\= (_, _) |
    integer(I, Code, Tail1),
    compile_value(Lst, Tag, SS, S1, S2, Tail1, ['K127:'|Tail2]),   % $$foreach
    compile_goal(Goal, SS, S2, S, PDefs, Tail2, Tail).
compile_foreach(Var, Lst, Goal, _, _, S1, S, _, Code, Tail) :-
    otherwise |
    Code := Tail, 
    compile_error('invalid syntax: ~q\n', [foreach(Var, Lst, Goal)], S1, S).

compile_when('$VAR'(Tag, I, Name), Goal, Tag, SS, S1, S, PDefs, Code, Tail) :-
    % XXX could check var for being singleton.
    compile_value('$VAR'(Tag, I, Name), Tag, SS, S1, S2, Code, ['gd'|Tail1]),
    compile_goal(Goal, SS, S2, S, PDefs, Tail1, Tail).
compile_when(Var, Goal, _, _, S1, S, _, Code, Tail) :-
    otherwise |
    Code := Tail,
    compile_error('invalid syntax: ~q\n', [when(Var, Goal)], S1, S).

compile_remote_call(MN:CALL, NODE, SS, S1, S, _, CODE, TAIL) :-
    functor(CALL, N, _, S1, S2),
    term:args(CALL, ARGS),
    list_to_tuple(ARGS, ARGV),
    % $call_remote/4
    compile_values([MN, N, ARGV, NODE], SS, S2, S, CODE, ['K8:'|TAIL]).
compile_remote_call(CALL, NODE, SS, S1, S, PDEFS, CODE, TAIL) :-
    functor(CALL, N, A, S1, S2),
    find_pdef(PDEFS, N, A, IX, S2, S3),
    term:args(CALL, ARGS),
    list_to_tuple(ARGS, ARGV),
    CODE := ['Hz', IX, ':'|TAIL1],
    % $call_remote/4
    compile_values([ARGV, NODE], SS, S3, S, TAIL1, ['K8:'|TAIL]).
compile_remote_call(CALL, _, _, S1, S, _, CODE, TAIL) :-
    otherwise | 
    CODE := TAIL,
    compile_error('invalid remote call: ~q\n', [CALL], S1, S).

compile_call(N, A, ARGS, SS, S1, S, PDEFS, CODE, TAIL) :-
    internal(N/A, K),
    compile_call1(K, N, A, ARGS, SS, S1, S, PDEFS, CODE, TAIL).

compile_call1(none, N, A, ARGS, SS, S1, S, PDEFS, CODE, TAIL) :-
    find_pdef(PDEFS, N, A, IX, S1, S2),
    compile_values(ARGS, SS, S2, S, CODE, ['J', IX, ':'|TAIL]).
compile_call1(K, _, _, ARGS, SS, S1, S, _, CODE, TAIL) :-
    K =\= none |
    compile_values(ARGS, SS, S1, S, CODE, ['K', K, ':'|TAIL]).

compile_foreign_call(CALL, _, S1, S, CODE, TAIL) :-
    string(CALL) |
    length(CALL, L),
    L2 is L + 2,
    CODE := ['Q', L2, ':', CALL, '/0'|TAIL], S := S1.
compile_foreign_call(CALL, SS, S1, S, CODE, TAIL) :-
    tuple(CALL) |
    tuple_to_list(CALL, TL, []),
    list:pair(TL, N, ARGS),
    length(ARGS, Arity),
    fmt:format_chars("~s/~d", [N, Arity], N2),
    list_to_string(N2, N2s),
    length(N2, NL),
    compile_values(ARGS, SS, S1, S, CODE, ['Q', NL, ':', N2s|TAIL]).
compile_foreign_call(CALL, _, S1, S, CODE, TAIL) :-
    otherwise |
    CODE := TAIL,
    compile_error('invalid foreign call: ~q\n', [CALL], S1, S).

% compile arithmetic expression

compile_expression(X, SS, S1, S, CODE, TAIL) :-
    var_tag(S1, VTAG),
    compile_expression1(X, VTAG, SS, X, S1, S, CODE, TAIL).

compile_expression1('$VAR'(TAG, I, _), TAG, SS, X, S1, S, CODE, TAIL) :-
    compile_expr_var(SS, I, X, S1, S, CODE, TAIL).
compile_expression1(X, _, _, _, S1, S, CODE, TAIL) :-
    integer(X) | 
    integer(X, CODE, TAIL), S := S1.
compile_expression1(X, VTAG, SS, X0, S1, S, CODE, TAIL) :-
    string(X) | 
    expr(X/0, K), 
    compile_expression2(K, X, VTAG, SS, X0, [], S1, S, CODE, TAIL).
compile_expression1(X, VTAG, SS, X0, S1, S, CODE, TAIL) :-
    tuple(X) | 
    tuple_to_list(X, XL, []),
    list:pair(XL, N, ARGS),
    length(ARGS, A),
    expr(N/A, K),
    compile_expression2(K, X, VTAG, SS, X0, ARGS, S1, S, CODE, TAIL).
compile_expression1(X, _, _, X0, S1, S, CODE, TAIL) :-
    otherwise | 
    CODE := TAIL, 
    compile_error('invalid expression: ~q in: ~q~n', [X, X0], S1, S).

compile_expression2(none, X, _, _, X0, _, S1, S, CODE, TAIL) :-
    CODE := TAIL,
    compile_error('unknown expression operator ~q in: ~q~n', [X, X0], S1, S).
compile_expression2(K, _, VTAG, SS, X0, ARGS, S1, S, CODE, TAIL) :-
    otherwise |
    compile_expressions(ARGS, VTAG, SS, X0, S1, S, CODE, [K|TAIL]).

compile_expr_var([], I, _, S1, S, CODE, TAIL) :-
    CODE := ['E', I, ':|'|TAIL], S := S1.
compile_expr_var([I|_], I, X, S1, S, CODE, TAIL) :-
    CODE := TAIL,
    compile_error('singleton variable in arithmetic expression: ~q~n', [X], S1, S).
compile_expr_var([J|R], I, X, S1, S, CODE, TAIL) :-
    J =\= I |
    compile_expr_var(R, I, X, S1, S, CODE, TAIL).

compile_expressions([], _, _, _, S1, S, CODE, TAIL) :- 
    CODE := TAIL, S := S1.
compile_expressions([X|R], VTAG, SS, X0, S1, S, CODE, TAIL) :-
    compile_expression1(X, VTAG, SS, X0, S1, S2, CODE, TAIL1),
    compile_expressions(R, VTAG, SS, X0, S2, S, TAIL1, TAIL).

% collect group of toplevel terms with same name + arity

group([], PDEFS, S1, S) :- 
    PDEFS := [], S := S1.
group([T|R], PDEFS, S1, S) :- 
    head(T, N, A, S1, S2), 
    PDEFS := [{N, A, [T|CS]}|PDEFS2],
    group1(R, N, A, CS, PDEFS2, S2, S).

group1([], _, _, CS, PDEFS, S1, S) :- 
    CS := [], PDEFS := [], S := S1.
group1([T|R], N, A, CS, PDEFS, S1, S) :-
    head(T, N2, A2, S1, S2), 
    group2(T, R, N, A, N2, A2, CS, PDEFS, S2, S).

group2(T, R, N, A, N, A, CS, PDEFS, S1, S) :-
    CS := [T|CS2],
    group1(R, N, A, CS2, PDEFS, S1, S).
group2(T, R, _, _, N2, A2, CS, PDEFS, S1, S) :-
    otherwise |
    CS := [],
    PDEFS := [{N2, A2, [T|CS2]}|PDEFS2],
    group1(R, N2, A2, CS2, PDEFS2, S1, S).

% support definitions

clause_parts((H :- T), HR, TR) :- HR := H, TR := T.
clause_parts(H, HR, TR) :- otherwise | HR := H, TR := true.

head((H :- _), N, A, S1, S) :- functor(H, N, A, S1, S).
head(T, N, A, S1, S) :- functor(T, N, A, S1, S).

functor(T, N, A, S1, S) :- 
    tuple(T) | 
    get_arg(1, T, N), length(T, LEN), A is LEN - 1, S := S1.
functor(T, N, A, S1, S) :-
    string(T) | N := T, A := 0, S := S1.
functor(T, N, A, S1, S) :-
    otherwise | 
    N := none, A := 0,
    compile_error('invalid process form: ~q\n', [T], S1, S).

find_pdef(PDEFS, N, A, IX, S1, S) :- 
    find_pdef1(PDEFS, N, A, 0, IX, S1, S).

find_pdef1([], N, A, _, IX, S1, S) :-
    IX := 0,
    compile_error('reference to undefined process: ~a/~d\n', [N, A], S1, S).
find_pdef1([{N, A, _}|_], N, A, I, IX, S1, S) :- 
    IX := I, S := S1.
find_pdef1([_|R], N, A, I, IX, S1, S) :- 
    otherwise | 
    I2 is I + 1, 
    find_pdef1(R, N, A, I2, IX, S1, S).

integer(I, CODE, TL) :-
    I >= 0, I =< 9 | CODE := [I|TL].
integer(I, CODE, TL) :-
    otherwise | CODE := ['I', I, ':'|TL].

integer_list([], CODE, TL) :- CODE := TL.
integer_list([I|L], CODE, TL) :-
    CODE := [I, ':'|TL1], integer_list(L, TL1, TL).

assignment_target('$VAR'(TAG, I, _), TAG, VI, S1, S) :- 
    VI := I, S := S1.
assignment_target(X, _, VI, S1, S) :- 
    otherwise | 
    VI := 0,
    compile_error('invalid assignment target: ~q~n', [X], S1, S).

non_circular_assignment(X, I, VTAG, S1, S) :- 
    tuple(X) | 
    non_circular_assignment2(X, I, VTAG, S1, S).
non_circular_assignment([X|R], I, VTAG, S1, S) :- 
    non_circular_assignment(X, I, VTAG, S1, S2),
    non_circular_assignment(R, I, VTAG, S2, S).
non_circular_assignment(_, _, _, S1, S) :- 
    otherwise | S := S1.

non_circular_assignment2('$VAR'(TAG, I, NAME), I, TAG, S1, S) :-
    compile_error('circular assignment: ~a~n', [NAME], S1, S).
non_circular_assignment2(X, I, VTAG, S1, S) :- 
    otherwise |
    tuple_to_list(X, L, []), 
    non_circular_assignment(L, I, VTAG, S1, S).

% error reporting

compile_error(FMT, ARGS, S1, S) :-
    emit_diagnostic({0, FMT, ARGS, 1}, S1, S).

compile_warning(FMT, ARGS, S1, S) :-
    emit_diagnostic({0, FMT, ARGS, 0}, S1, S).

% guards + primitive processes
    
guard('=='/2, K) :- K := '='.
guard('=\\='/2, K) :- K := '`'.
guard('=:='/2, K) :- K := 'm'/n.
guard('\\=:='/2, K) :- K := 'o'/n.
guard('>'/2, K) :- K := '>'/n.
guard('<'/2, K) :- K := '<'/n.
guard('>='/2, K) :- K := 'g'/n.
guard('=<'/2, K) :- K := 'l'/n.
guard('@>'/2, K) :- K := 'a'.
guard('@<'/2, K) :- K := 'b'.
guard('@>='/2, K) :- K := 'h'.
guard('@=<'/2, K) :- K := 's'.
guard(known/1, K) :- K := 'k'.
guard(unknown/1, K) :- K := 'u'.
guard(data/1, K) :- K := 'd'.
guard(string/1, K) :- K := 'c'.
guard(tuple/1, K) :- K := 't'.
guard(list/1, K) :- K := 'j'.
guard(integer/1, K) :- K := 'i'.
guard(module/1, K) :- K := 'q'.
guard(port/1, K) :- K := 'p'.
guard(idle/0, K) :- K := 'z'.
guard(bytes/1, K) :- K := 'n'.
guard(_, K) :- otherwise | K := none.

expr('+'/2, K) :- K := '+'.
expr('-'/2, K) :- K := '-'.
expr('*'/2, K) :- K := '*'.
expr('/'/2, K) :- K := '/'.
expr('\\\\'/2, K) :- K := '\\'.
expr(abs/1, K) :- K := '&'.
expr('/\\'/2, K) :- K := '^'.
expr('\\/'/2, K) :- K := 'v'.
expr('><'/2, K) :- K := 'x'.
expr('<<'/2, K) :- K := '{'.
expr('>>'/2, K) :- K := '}'.
expr('\\'/1, K) :- K := '~'.
expr('-'/1, K) :- K := '_'.
expr(isqrt/1, K) :- K := 'r'.
expr(clock/0, K) :- K := 'e'.
expr(max/2, K) :- K := 'W'.
expr(min/2, K) :- K := 'w'.
expr(_, K) :- otherwise | K := none.

internal('$reclaim'/2, K) :- K:= 0.
internal('$events'/1, K) :- K := 1.
internal('$send'/2, K) :- K := 2.
internal('$send'/3, K) :- K := 3.
internal(current_node/1, K) :- K := 4.
internal('$assign_remote'/3, K) :- K := 5.
internal('$get_exposed'/2, K) :- K := 6.
internal('$log'/1, K) :- K := 7.
internal('$call_remote'/4, K) :- K := 8.
internal('$call'/3, K) :- K := 9.
internal('$retrieve_module'/3, K) :- K := 10.
internal('$load_module'/2, K) :- K := 11.
internal(halt/1, K) :- K := 12.
internal(error/1, K) :- K := 13.
internal(write/1, K) :- K := 14.
internal(writeln/1, K) :- K := 15.
internal(string_to_list/3, K) :- K := 16.
internal(list_to_string/2, K) :- K := 17.
internal(make_tuple/2, K) :- K := 18.
internal(list_to_integer/2, K) :- K := 19.
internal(integer_to_list/2, K) :- K := 20.
internal(list_to_tuple/2, K) :- K := 21.
internal(tuple_to_list/3, K) :- K := 22.
internal(length/2, K) :- K := 23.
internal(run/2, K) :- K := 24.
internal(get_module/2, K) :- K := 25.
internal(assign/3, K) :- K := 26.
internal(put_arg/3, K) :- K := 27.
internal(put_arg/4, K) :- K := 28.
internal(get_arg/3, K) :- K := 29.
internal(get_arg/4, K) :- K := 30.
internal(open_file/3, K) :- K := 31.
internal(close_file/1, K) :- K := 32.
internal(read_bytes/3, K) :- K := 33.
internal(write_chars/2, K) :- K := 34.
internal(write/2, K) :- K := 35.
internal(merger/2, K) :- K := 36.
internal(list_to_integer/3, K) :- K := 37.
internal(integer_to_list/3, K) :- K := 38.
internal(byte_length/2, K) :- K := 39.
internal(write/3, K) :- K := 40.
internal(write_chars/3, K) :- K := 41.
internal(string_to_byte_list/3, K) :- K := 42.
internal(write_bytes/5, K) :- K := 43.
internal(write_bytes/3, K) :- K := 44.
internal(command_line/1, K) :- K := 45.
internal('$resolve_peer'/2, K) :- K := 46.
internal(utf_decode/3, K) :- K := 47.
internal('$register_peer'/2, K) :- K := 48.
internal(current_node/2, K) :- K := 49.
internal('$add_reference'/1, K) :- K := 50.
internal('$drop_reference'/1, K) :- K := 51.
internal(listen/2, K) :- K := 52.
internal('$forward'/2, K) :- K := 53.
internal('$deliver'/1, K) :- K := 54.
internal(strand_version/1, K) :- K := 55.
internal('$randomize'/2, K) :- K := 56.
internal('$statistics'/1, K) :- K := 57.
internal(close_file/2, K) :- K := 58.
internal(platform/2, K) :- K := 59.
internal(getenv/2, K) :- K := 60.
internal(shell/2, K) :- K := 61.
internal(open_pipe/2, K) :- K := 62.
internal('$execute'/7, K) :- K := 63.
internal('$read_forwarded'/2, K) :- K := 64.
internal(file_size/2, K) :- K := 65.
internal(file_modification_time/2, K) :- K := 66.
internal(string_to_integer/2, K) :- K := 67.
internal(string_to_integer/3, K) :- K := 68.
internal(run/4, K) :- K := 69.
internal(put_global/3, K) :- K := 70.
internal(get_global/2, K) :- K := 71.
internal(chdir/2, K) :- K := 72.
internal('$run'/5, K) :- K := 73.
internal(file_status/2, K) :- K := 74.
internal(time/1, K) :- K := 75.
internal(deref/2, K) :- K := 76.
internal(module_exports/2, K) :- K := 77.
internal(pledge/3, K) :- K := 100.
internal(unveil/3, K) :- K := 101.
internal(set_user_id/2, K) :- K := 102.
internal(open_port/2, K) :- K := 103.
internal('$module_data'/2, K) :- K := 104.
internal(send/2, K) :- K := 105.
internal('$assign_port'/2, K) :- K := 106.
internal(bytes_to_list/3, K) :- K := 107.
internal(send/3, K) :- K := 108.
internal(get_global/3, K) :- K := 109.
internal(list_to_bytes/2, K) :- K := 110.
internal(make_bytes/2, K) :- K := 111.
internal('$message_port_owner'/2, K) :- K := 112.
internal(writeln/2, K) :- K := 113.
internal(delete_file/2, K) :- K := 114.
internal(kill/3, K) :- K := 115.
internal('$put_bytes'/4, K) :- K := 116.
% 117
internal(get_bytes/5, K) :- K := 118.
internal(timer/2, K) :- K := 119.
internal(timer/3, K) :- K := 120.
internal(disable_timer/0, K) :- K := 121.
internal(make_bytes/3, K) :- K := 122.
internal(utf_encode/3, K) :- K := 123.
internal(pack/2, K) :- K := 124.
internal(unpack/2, K) :- K := 125.
internal(copy_bytes/4, K) :- K := 126.
% $$foreach (127)
internal(integer_to_list/4, K) :- K := 128.
internal('$inject_event'/1, K) :- K := 129.
% 130
internal(getcwd/1, K) :- K := 131.
internal(char_list_to_bytes/2, K) :- K := 132.
internal(bytes_to_char_list/3, K) :- K := 133.
internal(search_string/4, K) :- K := 134.
internal(search_string/3, K) :- K := 135.
internal(_, K) :- otherwise | K := none.

special(','/2, F) :- F := yes.
special(is/2, F) :- F := yes.
special(':='/2, F) :- F := yes.
special(current_module/1, F) :- F := yes.
special(true/0, F) :- F := yes.
special(when/2, F) :- F := yes.
special(foreach/3, F) :- F := yes.
special(_, F) :- otherwise | F := user.
