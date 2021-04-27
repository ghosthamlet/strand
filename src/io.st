% I/O support 
%
% 
% io:read_byte_stream(FILE?, BYTES^)
%   Read bytes from file into stream BYTES:
%
% io:read_char_stream(FILE?, CHARS^)
%   Read UTF characters from FILE into stream CHARS.
%
% io:decode_utf8(IN?, OUT^)
%   Converts the byte stream IN into a stream of UNICODE codepoints
%   in OUT.
%
% io:scan_line(LIST?, LINE^, TAIL^)
%   Scans characters from LIST until LF or CRLF and assign line and
%   remainder to LINE and TAIL, respectively.
%
% io:split_lines(LIST?, LINES^)
%   Split LIST into lines, terminated by LF or CRLF, generating stream 
%   LINES.

-exports([read_byte_stream/2, read_char_stream/2, decode_utf8/2]).
-exports([scan_line/3, split_lines/2]).

read_char_stream(FD, O) :-
    read_byte_stream(FD, O1),
    decode_utf8(O1, O).

read_byte_stream(FD, O) :-
    listen(FD, IN),
    read_byte_stream(IN, FD, O).

read_byte_stream([], FD, O) :-
    read_bytes(FD, 1024, B),
    bytes_to_list(B, O, TL),
    length(B, Count),
    read_byte_stream2(Count, FD, TL).

read_byte_stream2(0, _, TL) :- TL := [].
read_byte_stream2(N, FD, TL) :- 
    N > 0 |
    listen(FD, IN),
    read_byte_stream(IN, FD, TL).

decode_utf8([], O) :- O := [].
decode_utf8(I, O) :-
    I =\= [] |
    utf_decode(I, C, R),
    O := [C|O2],
    decode_utf8(R, O2).

scan_line([], LN, TAIL) :- LN := [], TAIL := [].
scan_line([10|R], LN, TAIL) :- LN := [], TAIL := R.
scan_line([13, 10|R], LN, TAIL) :- LN := [], TAIL := R.
scan_line([C|R], LN, TAIL) :-
    otherwise | LN := [C|LN2], scan_line(R, LN2, TAIL).

split_lines([], O) :- O := [].
split_lines(L, O) :-
    list(L) | O := [LN|O2], split_lines(L, LN, O2).

split_lines([10|R], LN, O) :- LN := [], split_lines(R, O).
split_lines([13, 10|R], LN, O) :- split_lines([10|R], LN, O).
split_lines([C|R], LN, O) :-
    otherwise |
    LN := [C|LN2], split_lines(R, LN2, O).
