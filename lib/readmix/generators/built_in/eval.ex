defmodule Readmix.Generators.BuiltIn.Eval do
  alias Readmix.Blocks.Generated
  alias Readmix.Context
  alias Readmix.Generators.BuiltIn.Section

  @moduledoc false

  def eval_block(params, context) do
    case Map.new(params) do
      %{section: _, code: _} ->
        {:error, "rdmx:eval does not accept both section and code parameters"}

      %{section: _} = params ->
        no_ansi(fn -> eval_section(params, context) end)

      %{code: _} = params ->
        no_ansi(fn -> eval_code(params, context) end)

      %{} ->
        {:error, "rdmx:eval missing one of section or code parameter"}
    end
  end

  defp no_ansi(fun) do
    ansi_enabled? = Application.get_env(:elixir, :ansi_enabled, false)
    Application.put_env(:elixir, :ansi_enabled, false)

    try do
      fun.()
    after
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled?)
    end
  end

  defp eval_section(params, context) do
    section_name = params.section

    with {:ok, %Generated{} = section} <- Context.lookup_rendered_section(context, section_name),
         {:ok, start_line, elixir_source} <- lookup_code_block(section),
         {:ok, quoted} <- string_to_quoted(elixir_source, section.spec.file, start_line),
         {:ok, eval_result} <- eval_code(quoted, params[:catch], section.spec.file, start_line) do
      {:ok, display_result(eval_result, params, context)}
    else
      {:error, _} = err -> err
    end
  end

  defp eval_code(params, context) do
    %{block: %{spec: %{file: file, loc: {line, _}}}} = context

    with {:ok, quoted} <- string_to_quoted(params.code, file, line),
         {:ok, eval_result} <- eval_code(quoted, params[:catch], file, line) do
      {:ok, display_result(eval_result, params, context)}
    end
  end

  defp lookup_code_block(section) do
    with {:ok, chunks} <- Section.to_chunks(section),
         {:code, "elixir", start_line, code} <- List.keyfind(chunks, :code, 0, :nochunk) do
      {:ok, start_line, code}
    else
      {:error, _} = err -> err
      :nochunk -> {:error, :not_found_code_block}
    end
  end

  defp string_to_quoted(elixir_source, file, start_line) do
    {:ok, Code.string_to_quoted!(elixir_source, file: file, line: start_line)}
  rescue
    e -> {:error, e}
  end

  @catch_tag :__catched_value__

  defp eval_code(quoted, true = _catch_errors?, file, line) do
    {:ok, Code.eval_quoted(quoted, [], file: file, line: line)}
  rescue
    CompileError -> {:error, :invalid_elixir_code}
    e -> {:ok, {@catch_tag, Exception.format_banner(:error, e, __STACKTRACE__)}}
  catch
    kind, e -> {:ok, {@catch_tag, Exception.format_banner(kind, e, __STACKTRACE__)}}
  end

  defp eval_code(quoted, false = _catch_errors, file, line) do
    {:ok, Code.eval_quoted(quoted, [], file: file, line: line)}
  rescue
    CompileError -> {:error, :invalid_elixir_code}
  end

  defp display_result({@catch_tag, banner}, _params, _ctx) when is_binary(banner) do
    """
    ```
    #{banner}
    ```
    """
  end

  @inspect_opts pretty: true, custom_options: [sort_maps: true]

  defp display_result({value, _bindings}, params, context) do
    if params.as_text do
      string =
        try do
          to_string(value)
        rescue
          Protocol.UndefinedError ->
            Context.error!(
              context,
              "output value #{inspect(value)} does not implement String.Chars"
            )
        end

      """
      #{string}
      """
    else
      """
      ```elixir
      #{inspect(value, @inspect_opts)}
      ```
      """
    end
  end
end
