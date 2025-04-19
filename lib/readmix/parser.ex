defmodule Readmix.Parser do
  @moduledoc """
  Parses documents for Readmix blocks embedded in HTML comments.

  This module handles parsing source documents containing tags in the following
  format:

  ```
  <!-- rdmx some_namespace:some_action param1:123 param2:"hello" -->
  content
  <!-- rdmx /some_namespace:some_action -->
  ```
  """

  alias Readmix.BlockSpec
  @external_resource "src/rdmx_parser.yrl"
  @external_resource "src/rdmx_lexer.xrl"

  defmodule ParseError do
    defexception [:kind, :loc, :source, :file, :arg]

    def message(%{kind: :illegal_block_end_params} = e) do
      "cannot set arguments on block end at #{e.file}:#{loc(e.loc)}: #{e.source}"
    end

    def message(%{kind: :unterminated_comment_tag} = e) do
      "HTML comment closing bracket not found #{e.file}:#{loc(e.loc)}: #{e.source}"
    end

    def message(%{kind: :syntax_error} = e) do
      case e.arg do
        {:illegal, chars} ->
          "syntax error before #{chars} in #{e.file}:#{loc(e.loc)}: #{e.source}"

        _ ->
          "parse error in #{e.file}:#{loc(e.loc)}: #{e.source}"
      end
    end

    def message(%{kind: :no_block_end} = e) do
      "no block end found for block start at #{e.file}:#{loc(e.loc)}: #{e.source}"
    end

    def message(%{kind: :no_block_start} = e) do
      "no block start found for block end at #{e.file}:#{loc(e.loc)}: #{e.source}"
    end

    defp loc({line, col}) do
      "#{line}:#{col}"
    end

    # Parser/lexer errors may contain location and/or source. In case they do not,
    # errors are always wrapped in a tuple with the loc/source of the parent
    # parser actionction.
    def convert_error({reason, loc, source}, file) do
      {kind, loc, source, arg} =
        case reason do
          simple
          when simple in [
                 :illegal_block_end_params,
                 :unterminated_comment_tag,
                 :no_block_end,
                 :no_block_start
               ] ->
            {simple, loc, source, nil}

          {{_line, _col} = loc, :rdmx_parser, msg} ->
            {:syntax_error, loc, source, msg}

          {999_999 = _no_loc, :rdmx_parser, msg} ->
            {:syntax_error, loc, source, msg}

          {{_, _} = loc, :rdmx_lexer, {:illegal, chars}} ->
            {:syntax_error, loc, source, {:illegal, chars}}
        end

      %ParseError{kind: kind, loc: loc, source: source, arg: arg, file: file}
    end
  end

  def parse_string(source, source_path) do
    chunks = parse_string(to_charlist(source), {1, 1}, [], [])
    blocks = build_blocks(chunks, source_path)
    {:ok, blocks}
  catch
    :throw, t -> {:error, ParseError.convert_error(t, source_path)}
  end

  @com_start_2 ~c"<!-- rdmx "
  @com_start_2_len length(@com_start_2)
  @com_start_3 ~c"<!--- rdmx "
  @com_start_3_len length(@com_start_3)
  @com_end_2 ~c"-->"
  @com_end_2_len length(@com_end_2)
  @com_end_3 ~c"--->"
  @com_end_3_len length(@com_end_3)

  defp parse_string(@com_start_3 ++ rest, loc, buffer, chunks) do
    chunks = append_raw_chunk(chunks, buffer)
    enter_generator_tag(rest, loc, @com_start_3, @com_start_3_len, _buffer = [], chunks)
  end

  defp parse_string(@com_start_2 ++ rest, loc, buffer, chunks) do
    chunks = append_raw_chunk(chunks, buffer)
    enter_generator_tag(rest, loc, @com_start_2, @com_start_2_len, _buffer = [], chunks)
  end

  defp parse_string([?\n | source], {line, _col}, buffer, chunks) do
    parse_string(source, {line + 1, 1}, [?\n | buffer], chunks)
  end

  defp parse_string([?\r, ?\n | source], {line, _col}, buffer, chunks) do
    parse_string(source, {line + 1, 1}, [?\n, ?\r | buffer], chunks)
  end

  defp parse_string([c | source], {line, col}, buffer, chunks) do
    parse_string(source, {line, col + 1}, [c | buffer], chunks)
  end

  defp parse_string([], _loc, buffer, chunks) do
    chunks = append_raw_chunk(chunks, buffer)
    :lists.reverse(chunks)
  end

  defp append_raw_chunk(chunks, []) do
    chunks
  end

  defp append_raw_chunk(chunks, buffer) do
    [{:text, List.to_string(:lists.reverse(buffer))} | chunks]
  end

  defp enter_generator_tag(rest, {line, col}, com_start_chars, com_start_len, buffer, chunks) do
    case parse_generator_tag(rest, com_start_chars, {line, col + com_start_len}) do
      {:ok, chunk, loc, rest} ->
        parse_string(rest, loc, buffer, [chunk | chunks])
    end
  end

  defp parse_generator_tag(source, html_com_start, loc) do
    # TODO to support "-->" into params we should stream the tokens and use
    # parse_and_scan for continuation on a yecc parser until it returns "end of
    # expression". Not sure if it is possible. For now we are looking for the
    # end of HTML comment tag, but it will match a "-->" in a string in the
    # generator.
    {content, end_comment, next_loc, rest} =
      case take_chunk_header(source, loc, []) do
        {_, _, _, _} = tuple -> tuple
        :eof -> throw({:unterminated_comment_tag, loc, html_com_start})
      end

    html_com = IO.iodata_to_binary([html_com_start, content, end_comment])

    # generator loc is from after the header, so loc instead of next_loc
    chunk =
      case parse_generator_call(content, loc, html_com) do
        {:block_start, ns, action, params} -> {:block_start, loc, {ns, action, params, html_com}}
        {:block_end, ns, action} -> {:block_end, loc, {ns, action, nil, html_com}}
      end

    {:ok, chunk, next_loc, rest}
  end

  defp take_chunk_header(@com_end_3 ++ rest, {line, col}, buffer) do
    {newlines, loc, rest} = take_one_newline(rest, {line, col + @com_end_3_len})
    {:lists.reverse(buffer), @com_end_3 ++ newlines, loc, rest}
  end

  defp take_chunk_header(@com_end_2 ++ rest, {line, col}, buffer) do
    {newlines, loc, rest} = take_one_newline(rest, {line, col + @com_end_2_len})
    {:lists.reverse(buffer), @com_end_2 ++ newlines, loc, rest}
  end

  defp take_chunk_header([?\r, ?\n | source], {line, _col}, buffer) do
    take_chunk_header(source, {line + 1, 1}, [?\n, ?\r | buffer])
  end

  defp take_chunk_header([?\n | source], {line, _col}, buffer) do
    take_chunk_header(source, {line + 1, 1}, [?\n | buffer])
  end

  defp take_chunk_header([char | source], {line, col}, buffer) do
    take_chunk_header(source, {line, col + 1}, [char | buffer])
  end

  defp take_chunk_header([], _, _) do
    :eof
  end

  defp take_one_newline([?\r, ?\n | source], {line, _col}) do
    {[?\r, ?\n], {line + 1, 1}, source}
  end

  defp take_one_newline([?\n | source], {line, _col}) do
    {[?\n], {line + 1, 1}, source}
  end

  defp take_one_newline(source, {line, col}) do
    {[], {line, col}, source}
  end

  defp parse_generator_call(raw_params, loc, source) do
    with {:ok, tokens, _} <- :rdmx_lexer.string(raw_params, loc),
         {:ok, ast} <- :rdmx_parser.parse(tokens) do
      ast
    else
      {:error, reason, {_, _}} -> throw({reason, loc, source})
      {:error, reason} -> throw({reason, loc, source})
    end
  catch
    {:illegal_block_end_params, loc} -> throw({:illegal_block_end_params, loc, source})
  end

  # to build nested blocks with same ns/action like sections we need to know
  # where to stop building the current block and return the rest to the higher
  # level.
  #
  # At the top level we want the full content so we fake an :"$eof" section/ns

  defp build_blocks(chunks, source_path) do
    {:ok, blocks, []} =
      build_blocks(chunks, source_path, _end_ns = :"$eof", _end_action = :"$eof", _acc = [])

    blocks
  end

  defp build_blocks([{:text, _} = raw | chunks], source_path, end_ns, end_action, acc),
    do: build_blocks(chunks, source_path, end_ns, end_action, [raw | acc])

  defp build_blocks([{:block_start, loc, header} | chunks], source_path, end_ns, end_action, acc) do
    {ns, action, _, raw_header} = header

    case build_blocks(chunks, source_path, ns, action, []) do
      {:ok, content, [{:block_end, _, footer} | chunks_rest]} ->
        block = wrap_block(header, footer, content, source_path, loc)
        build_blocks(chunks_rest, source_path, end_ns, end_action, [block | acc])

      {:ok, _, []} ->
        throw({:no_block_end, loc, raw_header})
    end
  end

  defp build_blocks(
         [{:block_end, _, {end_ns, end_action, _, _}} | _] = rest,
         _,
         end_ns,
         end_action,
         acc
       ) do
    {:ok, :lists.reverse(acc), rest}
  end

  defp build_blocks([{:block_end, loc, footer} | _], _, _, _, _acc) do
    {_, _, _, raw_footer} = footer
    throw({:no_block_start, loc, raw_footer})
  end

  defp build_blocks([], _, _, _, acc) do
    {:ok, :lists.reverse(acc), []}
  end

  defp wrap_block(
         {ns, action, params, raw_header},
         {ns, action, nil, raw_footer},
         content,
         source_path,
         loc
       ) do
    {:spec,
     %BlockSpec{
       raw_header: raw_header,
       raw_footer: raw_footer,
       generator: {ns, action, params},
       content: content,
       file: source_path,
       loc: loc
     }}
  end
end
