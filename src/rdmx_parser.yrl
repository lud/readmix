Nonterminals
  root
  command
  namespace_function
  params_list
  param_kv
  value
  .

Terminals
  identifier
  ':' '/'
  bool integer float string
  var
  .

Rootsymbol root.

Expect 0.

root ->     command : block_start('$1').
root -> '/' command : block_end('$2').

command -> namespace_function           : with_params_tokens('$1', []).
command -> namespace_function params_list : with_params_tokens('$1', '$2').

namespace_function ->            ':' identifier : {rdmx, id_name('$2')}.
namespace_function -> identifier ':' identifier : {id_name('$1'), id_name('$3')}.

params_list -> param_kv           : ['$1'].
params_list -> param_kv params_list : ['$1'|'$2'].

param_kv -> identifier ':' value : {id_name('$1'), meta_from_token('$1'), '$3'}.

value -> string     : valueof('$1').
value -> integer    : valueof('$1').
value -> float      : valueof('$1').
value -> bool       : valueof('$1').
value -> identifier : valueof('$1').
value -> var        : {var, var_name('$1')}.

Erlang code.

-compile({inline, meta_from_token/1, token_meta/1, id_name/1,valueof/1}).
-import(lists, [reverse/1, reverse/2]).

token_meta(Token) ->
  element(2, Token).

meta_from_token(Token) ->
  token_meta(Token).

id_name({identifier, _, Name}) ->
  binary_to_atom(Name).

var_name({var, _, Name}) ->
  binary_to_atom(Name).

valueof({_, _, Val}) ->
  Val.

with_params_tokens({NS, Action}, Params) ->
  {NS, Action, Params}.

block_start({NS, Action,  Params}) ->
  {block_start, NS, Action, build_params(Params)}.

build_params(Params) ->
  lists:map(fun({Ident, _, Value}) -> {Ident, Value} end, Params).

block_end({NS, Action, []}) ->
  {block_end, NS, Action};
block_end({_NS, _Action, [{_, Meta, _} | _]}) ->
  throw({illegal_block_end_params, Meta}).