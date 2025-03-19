Definitions.

% Literals
Bool        = (true|false)
Integer     = [0-9]
Float       = [0-9]+\.[0-9]+([eE][-+]?[0-9]+)?
String      = "(\\.|[^\"])*"


% delimiters / operators
Colon       = :
Slash       = /
Comma       = ,

% whitespace
WS          = ([\s\t\r\n]+)

% data paths / variables
Variable      = \$[a-zA-Z\_][a-zA-Z0-9\_]*
Identifier    =   [a-zA-Z\_][a-zA-Z0-9\_]*

Rules.

{Float}                  : to_token(float,   TokenLoc, TokenChars, fun erlang:list_to_float/1).
{Integer}+               : to_token(integer, TokenLoc, TokenChars, fun erlang:list_to_integer/1).
{String}                 : unwrap_quoted(string, TokenLoc, TokenChars, TokenLen).
{Bool}                   : to_token(bool, TokenLoc, TokenChars, fun list_to_existing_atom/1).
{Colon}                  : to_token(':', TokenLoc).
{Slash}                  : to_token('/', TokenLoc).
{Identifier}             : to_binary_token(identifier, TokenLoc, TokenChars).
{Variable}               : to_token(var, TokenLoc, TokenChars, fun variable_name/1).
{WS}                     : skip_token.
{Comma}                  : skip_token.

Erlang code.


to_token(Tag, Loc) ->
  {token, {Tag, Loc}}.

to_token(Tag, Loc, Chars, F) ->
  {token, {Tag, Loc, F(Chars)}}.

unwrap_quoted(Tag, Loc, Chars, Len) ->
  Unquoted = unescape(lists:sublist(Chars, 2, Len - 2), Loc),
  to_binary_token(Tag, Loc, Unquoted).

to_binary_token(Tag, Loc, Chars) ->
  to_token(Tag, Loc, Chars, fun 'Elixir.List':to_string/1).

variable_name([$$|Chars]) -> list_to_binary(Chars).

unescape(String, Loc) ->
  unescape(String, Loc, []).

unescape([], _Loc, Output) ->
  lists:reverse(Output);
unescape([$\\, Escaped | Rest], Loc, Output) ->
  Char = unescape_char(Escaped, Loc),
  unescape(Rest, Loc, [Char|Output]);
unescape([Char|Rest], Loc, Output) ->
  unescape(Rest, Loc, [Char|Output]).

unescape_char(Char, _Loc) ->
  case Char of
    $\" -> $\";
    $\' -> $\';
    $s  -> $\s;
    $t  -> $\t;
    $r  -> $\r;
    $n  -> $\n;
    $\\ -> $\\;
    _   -> Char % No escape
  end.
