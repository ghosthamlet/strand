% mandelbrot computation using torus topology
%
% uses algorithm from: https://rosettacode.org/wiki/Mandelbrot_set#B

-exports([main/0]).
-machine(torus).

main :- go(3*3).

go(DIMS) :-
    generate_map(DIMS, MAP),
    merger(MI, O),
    combine(MAP, MI),
    process(O, []),
    spread(DIMS, MAP).

% generate list of lists with input stream for each tile
generate_map(W*H, MAP) :-
    generate_map(0, H, W, MAP).

generate_map(H, H, _, MAP) :-
    MAP := [].
generate_map(N, H, W, MAP) :-
    N < H |
    make_tuple(W, ROW),
    tuple_to_list(ROW, ROWL, []),
    MAP := [ROWL|MAP2],
    N2 is N + 1,
    generate_map(N2, H, W, MAP2).

% merge tile streams into one
combine([], I) :- I := [].
combine([ROW|ROWS], I) :-
    combine2(ROW, I, I2),
    combine(ROWS, I2).

combine2([], I, I2) :- I := I2.
combine2([S|R], I, I2) :-
    I := [merge(S)|I3],
    combine2(R, I3, I2).

% spread computation over map of tiles
spread(W*H, MAP) :-
    spread_row(0, H, W, MAP).

spread_row(H, H, _, _).
spread_row(N, H, W, [ROW|ROWS]) :-
    N < H |
    spread_cols(0, W, N, W*H, ROW),
    N2 is N + 1,
    spread_row(N2, H, W, ROWS)@south.

spread_cols(W, W, _, _, _).
spread_cols(X, W, Y, DIMS, [S|ROW]) :-
    X < W |
    work(X, Y, DIMS, S),
    X2 is X + 1,
    spread_cols(X2, W, Y, DIMS, ROW)@east.

% worker
work(X, Y, W*H, S) :-
    Iw is 2867 - -8601,
    Ih is 4915 - -4915,
    Dx is Iw / 119,
    Dy is Ih / 39,
    Tw is Iw / W,
    Th is Ih / H,
    Xmin is -8601 + (Tw * X),
    Ymin is -4915 + (Th * Y),
    Xmax is -8601 + (Tw * (X + 1)),
    Ymax is -4915 + (Th * (Y + 1)),
    Px is X * (Tw / Dx),
    Py is Y * (Th / Dy),
    loop_y(Ymin, Ymax, Xmin, Xmax, Px, Py, Dx, Dy, S).

loop_y(Y, Ymax, _, _, _, _, _, _, S) :- 
    Y >= Ymax | S := [].
loop_y(Y, Ymax, Xmin, Xmax, Px, Py, Dx, Dy, S) :-
    Y < Ymax |
    loop_x(Xmin, Xmax, Y, Dx, Px, Py, S, S2),
    Yn is Y + Dy,
    Py2 is Py + 1,
    loop_y(Yn, Ymax, Xmin, Xmax, Px, Py2, Dx, Dy, S2).

loop_x(X, Xmax, _, _, _, _, S, S2) :- 
    X >= Xmax | S := S2.
loop_x(X, Xmax, Y, Dx, Px, Py, S, S2) :-
    X < Xmax |
    iter(0, 0, Xmax, X, Y, 0, 0, 0, 0, Dx, Px, Py, S, S2).

iter(I, XY, Xmax, X, Y, X1, Y1, X2, Y2, Dx, Px, Py, S, S2) :-
    I < 32, XY =< 16384 |
    Y1n is (X1 * Y1) >> 11 + Y,
    X1n is (X2 - Y2) + X,
    X2n is (X1 * X1) >> 12,
    Y2n is (Y1 * Y1) >> 12,
    In is I + 1,
    XYn is X2n + Y2n,
    iter(In, XYn, Xmax, X, Y, X1n, Y1n, X2n, Y2n, Dx, Px, Py, S, S2).
iter(I, _, Xmax, X, Y, _, _, _, _, Dx, Px, Py, S, S2) :-
    otherwise | 
    C is 32 + I, 
    S := [{Px, Py, C}|S3], 
    Xn is X + Dx,
    Px2 is Px + 1,
    loop_x(Xn, Xmax, Y, Dx, Px2, Py, S3, S2).

% processor
process([], []) :- 
    fmt:format('~c[40;1H~n', [27]).
process([{X, Y, C}|I], []) :-
    show(X, Y, C, OK),
    process(I, OK).

show(X, Y, CH, OK) :-
    R is Y + 1, C is X + 1,
    fmt:format('~c[~d;~dH~c', [27, R, C, CH], OK).
