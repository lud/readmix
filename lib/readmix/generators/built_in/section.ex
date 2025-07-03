defmodule Readmix.Generators.BuiltIn.Section do
  alias Readmix.Blocks.Generated

  @moduledoc false

  def generate_section(params, context) do
    %{previous_content: prev, readmix: rdmx} = context

    case Readmix.blocks_to_iodata(rdmx, prev) do
      {:error, _} = err ->
        err

      {:ok, iodata} ->
        case params[:format] do
          true -> {:ok, format_code_blocks(iodata, context.block)}
          _ -> {:ok, iodata}
        end
    end
  end

  defp format_code_blocks(iodata, %Generated{} = section) do
    %Generated{
      spec: %{raw_header: raw_header, file: file, loc: {line, _col}}
    } = section

    case to_chunks(raw_header, iodata, line) do
      {:ok, chunks} -> Enum.map(chunks, &format_chunk(&1, file))
    end
  end

  @doc """
  Slices the given section content into tuples, either `{:text, string}` or
  `{:code, language, line code}`. Currently only parses Elixir code blocks, so
  `language` is always `"elixir"`.

  Requires the section to have been rendered.
  """
  def to_chunks(%Generated{rendered: {header, rendered_content, _}} = section) do
    %Generated{spec: %{loc: {line, _col}}} = section

    to_chunks(header, rendered_content, line)
  end

  defp to_chunks(header, rendered_content, line) do
    rendered = IO.iodata_to_binary(rendered_content)
    line = count_newlines(header, line)
    slice_chunks(rendered, line, [])
  end

  defp slice_chunks(<<"```elixir", rest::binary>>, line, acc) do
    case collect_code_block(rest, line, []) do
      {:ok, {code, next_line, rest}} ->
        chunk = {:code, "elixir", line, code}

        slice_chunks(rest, next_line, [chunk | acc])

      {:error, _} = err ->
        err
    end
  end

  defp slice_chunks(<<?n, rest::binary>>, line, acc) do
    slice_chunks(rest, line + 1, [?n | acc])
  end

  defp slice_chunks(<<c::utf8, rest::binary>>, line, acc) do
    slice_chunks(rest, line, [c | acc])
  end

  defp slice_chunks(<<>>, _, acc) do
    {:ok, build_chunks(acc)}
  end

  defp collect_code_block(<<"```", rest::binary>>, line, acc) do
    code = acc |> :lists.reverse() |> List.to_string()
    {:ok, {code, line, rest}}
  end

  defp collect_code_block(<<?n, rest::binary>>, line, acc) do
    collect_code_block(rest, line + 1, [?n | acc])
  end

  defp collect_code_block(<<c::utf8, rest::binary>>, line, acc) do
    collect_code_block(rest, line, [c | acc])
  end

  defp collect_code_block(<<>>, _, _acc) do
    {:error, :unfinished_code_block}
  end

  defp build_chunks(rev_chunks) do
    rev_chunks
    |> :lists.reverse()
    |> Enum.chunk_by(&is_integer/1)
    |> Enum.flat_map(fn
      [{:code, _, _, _} | _] = codes -> codes
      [n | _] = ints when is_integer(n) -> [{:text, List.to_string(ints)}]
    end)
  end

  defp count_newlines(<<?\n, rest::binary>>, n), do: count_newlines(rest, n + 1)
  defp count_newlines(<<_, rest::binary>>, n), do: count_newlines(rest, n)
  defp count_newlines(<<>>, n), do: n

  defp format_chunk({:text, text}, _), do: text

  defp format_chunk({:code, "elixir", line, code}, file) do
    {_, formatter_opts} = Mix.Tasks.Format.formatter_for_file(file)

    opts =
      Keyword.merge(formatter_opts,
        file: file,
        line: line,
        migrate: true,
        force_do_end_blocks: false
      )

    try do
      new_code = Code.format_string!(code, opts)
      ["```elixir\n", new_code, "\n```"]
    rescue
      e ->
        IO.warn(Exception.message(e))
        # newlines from original code are preserved
        ["```elixir", code, "```"]
    end
  end
end
