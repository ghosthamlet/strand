% taken from graphs.pl, by R. A. O'Keefe
%
%    The P-representation of a graph is a list of (from-to) vertex
%     pairs, where the pairs can be in any old order.  This form is
%     convenient for input/output.
% 
%     (Note [KJ] The representation of a link in the Pform,
%     e.g.edinburgh-glasgow, does not imply the existence of a
%     link from glasgow to edinburgh. You have to put that in separately.)
% 
%     The S-representation of a graph is a list of (vertex-neighbours)
%     pairs, where the pairs are in standard order (as produced by
%     keysort) and the neighbours of each vertex are also in standard
%     order (as produced by sort).  This form is convenient for many
%     calculations.

-exports([p_to_s_graph/2, top_sort/2]).


% converts arbitrarily ordered (from-to) vertex pair list (P-representation)
% to S-representation with sorted elements:

p_to_s_graph(P_Graph, S_Graph) :-
    sort:sort(P_Graph, EdgeSet),
    p_to_s_vertices(EdgeSet, VertexBag),
    sort:sort(VertexBag, VertexSet),
    p_to_s_group(VertexSet, EdgeSet, S_Graph).

p_to_s_vertices([], Bag) :- Bag := [].
p_to_s_vertices([A-Z|Edges], Bag) :-
    Bag := [A,Z|Vertices],
    p_to_s_vertices(Edges, Vertices).

p_to_s_group([], _, G) :- G := [].
p_to_s_group([Vertex|Vertices], EdgeSet, G) :-
    p_to_s_group(EdgeSet, Vertex, Neibs, RestEdges),
    p_to_s_group(Vertices, RestEdges, G2),
    G := [Vertex-Neibs|G2].

p_to_s_group([V-X|Edges], V, Neibs, RestEdges) :-
    p_to_s_group(Edges, V, Neibs2, RestEdges),
    Neibs := [X|Neibs2].
p_to_s_group(Edges, _, Neibs, RE) :- 
    Neibs := [],
    RE := Edges.

% topological sort, assumes input-graph is in S-representation:

top_sort(Graph, Sorted) :-
    vertices_and_zeros(Graph, Vertices, Counts0),
    count_edges(Graph, Vertices, Counts0, Counts1),
    select_zeros(Counts1, Vertices, Zeros),
    top_sort(Zeros, Sorted, Graph, Vertices, Counts1).

vertices_and_zeros([], V, C) :- V := [], C := [].
vertices_and_zeros([Vertex-_|Graph], V, C) :-
    V := [Vertex|Vertices], 
    C := [0|Zeros],
    vertices_and_zeros(Graph, Vertices, Zeros).

count_edges([], _, Counts, C) :- C := Counts.
count_edges([_-Neibs|Graph], Vertices, Counts0, Counts2) :-
    incr_list(Neibs, Vertices, Counts0, Counts1),
    count_edges(Graph, Vertices, Counts1, Counts2).

incr_list([], _, Counts, C) :- C := Counts.
incr_list([V1|Neibs], [V1|Vertices], [M|Counts0], C) :-
    N is M+1,
    C := [N|Counts1],
    incr_list(Neibs, Vertices, Counts0, Counts1).
incr_list(Neibs, [_|Vertices], [N|Counts0], C) :-
    otherwise | 
    C := [N|Counts1],
    incr_list(Neibs, Vertices, Counts0, Counts1).

select_zeros([], [], Z) :- Z := [].
select_zeros([0|Counts], [Vertex|Vertices], Z) :-
    Z := [Vertex|Zeros],
    select_zeros(Counts, Vertices, Zeros).
select_zeros([N|Counts], [_|Vertices], Zeros) :-
    N =\= 0 |
    select_zeros(Counts, Vertices, Zeros).

top_sort([], S, Graph, _, Counts) :-
    vertices_and_zeros(Graph, _, Counts2),
    top_sort1(Counts, Counts2, S).
top_sort([Zero|Zeros], S, Graph, Vertices, Counts1) :-
    graph_memberchk(Zero-Neibs, Graph),
    decr_list(Neibs, Vertices, Counts1, Counts2, Zeros, NewZeros),
    top_sort(NewZeros, Sorted, Graph, Vertices, Counts2),
    top_sort2(Zero, Sorted, S).

top_sort1(C, C, S) :- S := [].
top_sort1(C1, C2, S) :- C1 =\= C2 | S := failed.

top_sort2(_, failed, S) :- S := failed.
top_sort2(Zero, Sorted, S) :- otherwise | S := [Zero|Sorted].

graph_memberchk(Element1-Edges, [Element2-Edges2|_]) :-
    Element1 == Element2 | 
    Edges := Edges2.
graph_memberchk(Element, [_|Rest]) :-
    otherwise | graph_memberchk(Element, Rest).

decr_list([], _, Counts, C, Zeros, Z) :- C := Counts, Z := Zeros.
decr_list([V1|Neibs], [V1|Vertices], [1|Counts1], C, Zi, Zo) :-
    C := [0|Counts2],
    decr_list(Neibs, Vertices, Counts1, Counts2, [V1|Zi], Zo).
decr_list([V1|Neibs], [V1|Vertices], [N|Counts1], C, Zi, Zo) :-
    M is N-1,
    C := [M|Counts2],
    decr_list(Neibs, Vertices, Counts1, Counts2, Zi, Zo).
decr_list(Neibs, [_|Vertices], [N|Counts1], C, Zi, Zo) :-
    otherwise | 
    C := [N|Counts2],
    decr_list(Neibs, Vertices, Counts1, Counts2, Zi, Zo).
