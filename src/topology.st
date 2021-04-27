% topology building
%
% topology:ring(ITEMS?, RING^)
%   Takes elements from the list ITEMS, constructs an association list
%   of the form [[ITEM1, [bwd|ITEM2], [fwd|ITEM3]], ...] and assigns it to RING.
%
% topology:torus([ITEMS?, TORUS^)
%   Constructs a torus topology of the form
%   [[ITEM1, [north|ITEM2], [east|ITEM3], [south|ITEM4], [west|ITEM5]], ...]
%   and assigns it to TORUS.

-exports([ring/2, torus/2]).

ring([N1|ALL], RING) :-
    ALL =\= [] |
    RING := [[N1, [bwd|LAST], [fwd|NEXT]]|RING2],
    ring2(ALL, N1, NEXT, N1, LAST, RING2).
ring(_, RING) :- 
    otherwise |
    current_node(SELF),
    writeln(error(SELF, 'too few nodes for building ring')),
    RING := [].

ring2([N], PREV, NEXT, FIRST, LAST, RING) :-
    LAST := N,
    NEXT := N,
    RING := [[N, [bwd|PREV], [fwd|FIRST]]].
ring2([N|ALL], PREV, NEXT, FIRST, LAST, RING) :-
    ALL =\= [] |
    NEXT := N,
    RING := [[N, [bwd|PREV], [fwd|NEXT2]]|RING2],
    ring2(ALL, N, NEXT2, FIRST, LAST, RING2).

torus(ALL, TORUS) :-
    length(ALL, N),
    torus_dimensions(N, W, H),
    list_to_tuple(ALL, AT),
    NT is W * H,
    torus2(1, NT, 0, 0, AT, W, H, TORUS).

torus_dimensions(N, W, H) :-
    H is isqrt(N),
    W is H + (N - H * H) / H.

torus2(P, N, _, _, _, _, _, TORUS) :- 
    P > N | TORUS := [].
torus2(P, N, X, Y, AT, W, H, TORUS) :-
    P =< N |
    get_arg(P, AT, NODE),
    NN1 is Y - 1, wrap(X, NN1, W, H, NN2), get_arg(NN2, AT, NN),
    EN1 is X + 1, wrap(EN1, Y, W, H, EN2), get_arg(EN2, AT, EN),
    SN1 is Y + 1, wrap(X, SN1, W, H, SN2), get_arg(SN2, AT, SN),
    WN1 is X - 1, wrap(WN1, Y, W, H, WN2), get_arg(WN2, AT, WN),
    TORUS := [[NODE, [north|NN], [east|EN], [south|SN], [west|WN]]|T2],
    P2 is P + 1,
    torus3(P2, N, EN1, Y, AT, W, H, T2).

torus3(P2, N, W, Y, AT, W, H, T2) :-
    Y2 is Y + 1,
    torus2(P2, N, 0, Y2, AT, W, H, T2).
torus3(P2, N, X, Y, AT, W, H, T2) :-
    X < W |
    torus2(P2, N, X, Y, AT, W, H, T2).

wrap(-1, Y, W, _, P) :- P is Y * W + W - 1 + 1.
wrap(X, -1, W, H, P) :- P is (H - 1) * W + X + 1.
wrap(W, Y, W, _, P) :- P is Y * W + 1.
wrap(X, H, _, H, P) :- P is X + 1.
wrap(X, Y, W, _, P) :- otherwise | P is Y * W + X + 1.
