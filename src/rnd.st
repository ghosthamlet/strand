% random numbers
%
%   rnd:pseudo_random_state(SEED?, STATE^)
%       Assign a new pseudo-random generator state from the integer SEED
%       and assign it to STATE.
%
%   rnd:pseudo_random_integer(RND^, STATE^)
%   rnd:pseudo_random_integer(STATE1?, RND^, STATE^) 
%   rnd:pseudo_random_integer(STATE1?, LIMIT?, RND^, STATE^) 
%       Produce a pseudo random integer RND, seeded by SEED or the
%       current time. If LIMIT is given, numbers are clamped to an interval 
%       between 0 and (not including) LIMIT. STATE1 designates the initial
%       random-number generator state and STATE the new state which is
%       the result of creating RND.
%
%   rnd:random_bytes(N?, S^)
%       Produce N random bytes on stream S, reading from /dev/urandom.

-exports([pseudo_random_state/2, pseudo_random_integer/2, 
    pseudo_random_integer/3, pseudo_random_integer/4]).
-exports([random_bytes/2]).

random_bytes(N, S) :-
    open_file('/dev/urandom', r, FD),
    read_bytes(FD, N, B),
    bytes_to_list(B, S, []),
    close_file(FD).

pseudo_random_state(SEED, S) :- S := {SEED}.

pseudo_random_integer(R, S) :-
    time(T0),
    pseudo_random_integer({T0}, R, S).

pseudo_random_integer({SEED}, R, S) :-
    '$randomize'(SEED, R),
    S := {R}.

pseudo_random_integer(S1, LIMIT, R, S) :-
    pseudo_random_integer(S1, R1, S),
    R is abs(R1) \\ LIMIT.
