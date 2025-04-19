defmodule Readmix.Generators.BuiltIn.Eval do
  require Readmix.Records, as: Records
  alias Readmix.Context

  @moduledoc false

  def eval_section(params, context) do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled, false)
    Application.put_env(:elixir, :ansi_enabled, false)

    try do
      do_eval_section(params, context)
    after
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end
  end

  def do_eval_section(params, context) do
    section_name = Keyword.fetch!(params, :section)

    with {:ok, Records.generated(rendered: {_, source_block_content, _}) = section} <-
           Context.lookup_rendered_section(context, section_name),
         source_block_content = IO.iodata_to_binary(source_block_content),
         {:ok, elixir_source} <- strip_code_fences(source_block_content),
         {:ok, quoted} <- string_to_quoted(elixir_source, section),
         {:ok, eval_result} <- eval_code(quoted, params[:catch]) do
      {:ok, display_result(eval_result)}
    else
      {:error, _} = err -> err
    end
  end

  defp strip_code_fences(source_block_content) do
    source_block_content
    |> String.trim()
    |> case do
      "```elixir" <> rest -> {:ok, strip_fence_end(rest)}
      "```" <> rest -> {:ok, strip_fence_end(rest)}
      _ -> {:error, :invalid_code_block}
    end
  end

  defp strip_fence_end(source_block_content) do
    source_block_content
    |> String.trim_leading(" ")
    |> case do
      "\n" <> rest -> String.trim_trailing(rest, "`")
      _other -> {:error, :invalid_code_block}
    end
  end

  defp string_to_quoted(elixir_source, section) do
    Records.generated(rendered: {header, _, _}, spec: %{loc: {line, _col}, file: file}) = section
    # add +1 line for code fences
    # add newlines from block header
    start_line = line + 1 + count_newlines(header, 0)

    {:ok, Code.string_to_quoted!(elixir_source, file: file, line: start_line)}
  rescue
    e -> {:error, e}
  end

  defp count_newlines(<<?\n, rest::binary>>, n), do: count_newlines(rest, n + 1)
  defp count_newlines(<<_, rest::binary>>, n), do: count_newlines(rest, n)
  defp count_newlines(<<>>, n), do: n

  @catch_tag :__catched_value__

  defp eval_code(quoted, true = _catch_errors) do
    {:ok, Code.eval_quoted(quoted)}
  rescue
    CompileError -> {:error, :invalid_code}
    e -> {:ok, {@catch_tag, Exception.format_banner(:error, e, __STACKTRACE__)}}
  catch
    kind, e -> {:ok, {@catch_tag, Exception.format_banner(kind, e, __STACKTRACE__)}}
  end

  defp eval_code(quoted, _catch_errors) do
    {:ok, Code.eval_quoted(quoted)}
  rescue
    CompileError -> {:error, :invalid_elixir_code}
  end

  defp display_result({@catch_tag, banner}) when is_binary(banner) do
    """
    ```
    #{banner}
    ```
    """
  end

  @inspect_opts pretty: true, custom_options: [sort_maps: true]

  defp display_result({value, _bindings}) do
    """
    ```elixir
    #{inspect(value, @inspect_opts)}
    ```
    """
  end
end
