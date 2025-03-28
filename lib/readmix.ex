defmodule Readmix do
  alias Readmix.BlockSpec
  alias Readmix.Context
  alias Readmix.Contexts.Defaults

  @moduledoc """
  Readmix is a tool for generating and maintaining documentation with dynamic
  content.

  It allows you to embed special tags in your markdown or other text files that
  will be processed and replaced with generated content.

  ## Basic Usage

  ```elixir
  # Create a new Readmix instance
  rdmx = Readmix.new([])

  # Update a file containing Readmix blocks
  Readmix.update_file(rdmx, "README.md")
  ```

  ## Block Format

  Readmix blocks are defined in HTML comments with a special `rdmx` prefix:

  ```
  <!-- rdmx my_namespace:my_action param1:"value1" param2:$my_var -->
  This content will be replaced by the generator.
  <!-- rdmx my_namespace:my_action -->
  ```

  ## Configuration

  You can configure Readmix with custom generators, variables, and context
  modules:

  ```elixir
  Readmix.new(
    generators: %{my_namespace: MyGeneratorModule},
    vars: %{my_var: "hello"},
    contexts: [MyContext | Readmix.default_contexts()]
  )
  ```
  """

  defstruct [:resolver, :vars, :backup_fun]

  @type t :: %__MODULE__{
          resolver: function(),
          backup_fun: function(),
          vars: %{optional(atom) => term}
        }

  def new(opts) do
    %__MODULE__{
      resolver: opt_resolver(opts),
      vars: opt_vars(opts),
      backup_fun: opt_backup(opts)
    }
  end

  @actions_schema NimbleOptions.new!(
                    *: [
                      type: :keyword_list,
                      keys: [
                        as: [type: :atom],
                        params: [
                          type: :keyword_list
                          # TODO maybe await https://github.com/dashbitco/nimble_options/issues/141
                          # keys: NimbleOptions.options_schema()
                          #
                          # It's not going to happen anytime soon thoug.
                        ],
                        doc: [type: :string]
                      ]
                    ]
                  )

  defp opt_resolver(opts) do
    add_generators =
      case opts[:generators] do
        nil -> config_generators()
        mods -> mods
      end

    generators = Enum.into(add_generators, default_generators())

    Map.new(generators, fn {ns, mod} ->
      actions =
        mod.actions()
        |> NimbleOptions.validate!(@actions_schema)
        |> Map.new(fn {action, spec} ->
          params = Keyword.get(spec, :params, [])
          params = build_params_schema(params, ns, mod, action)
          {action, params}
        end)

      {ns, {mod, actions}}
    end)
  end

  defp build_params_schema(raw_schema, ns, mod, action) do
    NimbleOptions.new!(raw_schema)
  rescue
    e ->
      reraise ArgumentError,
              "invalid action parameters for action #{inspect(action)} of #{inspect(mod)} (mapped as #{inspect(ns)}), " <>
                ":params should be a valid NimbleOptions schema,\n\n" <> Exception.message(e),
              __STACKTRACE__
  end

  defp opt_vars(opts) do
    external_vars =
      case opts[:vars] do
        vars when is_map(vars) -> vars
        nil -> %{}
        other -> raise "invalid option :vars, expected a map, got: #{inspect(other)}"
      end

    # Unlike generators, the default contexts are not pulled if the
    # configuration is set.
    #
    # config_contexts() returns default_contexts() if the configuration is not
    # set.
    contexts =
      case opts[:contexts] do
        nil -> Readmix.config_contexts()
        list when is_list(list) -> list
      end

    # Modules defined first in the list have precedence, subsequent modules do
    # not overwrite their vars. The external vars have precedence over all
    # modules.
    Enum.reduce(contexts, external_vars, fn mod, acc ->
      case mod.get_vars() do
        map when is_map(map) ->
          Map.merge(mod.get_vars(), acc)

        other ->
          raise "invalid return value from #{inspect(mod)}.get_vars/0, expected a map, got: #{inspect(other)}"
      end
    end)
  end

  defp opt_backup(opts) do
    case Keyword.get(opts, :backup?, true) do
      true ->
        backup_root_dir = Keyword.get_lazy(opts, :backup_dir, &default_backup_directory/0)

        call_time =
          case opts[:backup_datetime] do
            %DateTime{} = dt -> dt
            nil -> DateTime.utc_now()
          end

        make_backup_callback(backup_root_dir, call_time)

      _ ->
        _no_backup = fn _, _ -> :ok end
    end
  end

  @doc """
  Returns the default backup directory for updated files.

  Readmix will append the otp_app name to the path so it is safe to use the same
  directory for multiple applications.
  """
  def default_backup_directory do
    Path.join(System.tmp_dir(), "readmix-backups")
  end

  defp make_backup_callback(backup_root_dir, call_time) do
    stamp = Calendar.strftime(call_time, "%x--%H-%M-%S--%f")

    backup_dir =
      Path.join([
        backup_root_dir,
        Atom.to_string(Defaults.otp_app()),
        stamp
      ])

    File.mkdir_p!(backup_dir)

    fn orginal_path, content ->
      sub_path =
        case orginal_path do
          "/" <> sub_abs_path -> sub_abs_path
          rel_path -> rel_path
        end

      target_path = Path.join(backup_dir, sub_path)

      if File.exists?(target_path) do
        raise "cannot backup #{orginal_path} to #{target_path}, file exists"
      end

      with :ok <- File.mkdir_p!(Path.dirname(target_path)),
           :ok <- File.write(target_path, content) do
        CliMate.CLI.writeln("Wrote backup of #{orginal_path} in #{target_path}")
        :ok
      else
        {:error, _} = err -> err
      end
    end
  end

  @doc false
  def default_generators do
    %{rdmx: Readmix.Generators.BuiltIn}
  end

  @doc false
  def config_generators do
    Application.get_env(:readmix, :generators, %{})
  end

  @doc """
  Returns the default contexts used for built-in generators.

  If you need to configure your own contexts but want to use Readmix generators
  as well, include those contexts in the configuration:

      # config/dev.exs
      import Config

      config :readmix,
        contexts: [MyContext1, MyContext2 | Readmix.default_contexts()]
  """
  def default_contexts do
    [Readmix.Contexts.Defaults]
  end

  @doc false
  def config_contexts do
    Application.get_env(:readmix, :contexts, default_contexts())
  end

  def update_file(rdmx, path) do
    with {:ok, content} <- read_source(path),
         {:ok, iodata} <- transform_string(rdmx, content, source_path: path),
         :ok <- call_backup(rdmx, path, content) do
      File.write(path, iodata)
    else
      {:error, reason} -> {:error, convert_error(reason, path)}
    end
  end

  defp read_source(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:file_error, path, reason}}
    end
  end

  defp call_backup(rdmx, path, content) do
    rdmx.backup_fun.(path, content)
  end

  def transform_string(rdmx, string, opts \\ [])

  def transform_string(rdmx, string, opts) do
    with {:ok, iodata} <- transform_string_to_iodata(rdmx, string, opts) do
      {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  def transform_string_to_iodata(rdmx, string, opts \\ [])

  def transform_string_to_iodata(rdmx, string, opts) when is_binary(string) do
    with {:ok, blocks} <- parse_string(string, opts[:source_path]) do
      blocks_to_iodata(rdmx, blocks)
    end
  end

  def parse_string(string, source_path \\ nil)

  def parse_string(string, nil) do
    parse_string(string, "nofile")
  end

  def parse_string(string, source_path) do
    Readmix.Parser.parse_string(string, source_path)
  end

  def blocks_to_iodata(rdmx, blocks) do
    result =
      Enum.reduce_while(blocks, {:ok, []}, fn block, {:ok, acc} ->
        case block_to_iodata(rdmx, block) do
          {:ok, new_block} -> {:cont, {:ok, [new_block | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:ok, rev} -> {:ok, :lists.reverse(rev)}
      {:error, _} = err -> err
    end
  end

  defp block_to_iodata(_rdmx, {:text, iodata}), do: {:ok, iodata}

  defp block_to_iodata(rdmx, {:generated, block}) do
    %{
      generator: {ns, action, params},
      raw_header: raw_header,
      raw_footer: raw_footer,
      content: sub_blocks
    } = block

    # We do not use the :as param of an action. This is for the macro. We will
    # always call the generate/3 callback.
    try do
      with {:ok, {mod, params}} <- resolve_call(rdmx, ns, action, params),
           {:ok, iodata} <- call_transformer(rdmx, mod, action, params, sub_blocks) do
        {:ok, [raw_header, iodata, raw_footer]}
      else
        {:error, reason} -> {:error, convert_error(reason, block)}
      end
    catch
      :throw, {:undef_var, _} = e -> {:error, convert_error(e, block)}
    end
  end

  defp resolve_call(rdmx, ns, action, params_in) do
    with {:ok, {mod, actions}} <- resolve_mod(rdmx, ns),
         errctx = {ns, mod, action},
         {:ok, params_schema} <- resolve_fun(actions, action, errctx),
         {:ok, params} <- swap_variables(rdmx, params_in),
         {:ok, params} <- validate_params(params, params_schema, errctx) do
      {:ok, {mod, params}}
    end
  end

  defp resolve_mod(rdmx, ns) do
    case Map.fetch(rdmx.resolver, ns) do
      {:ok, {mod, actions}} when is_atom(mod) ->
        {:ok, {mod, actions}}

      {:ok, other} ->
        raise "invalid mapped generator: #{inspect(other)}"

      :error ->
        {:error, {:unresolved_generator, ns}}
    end
  end

  defp resolve_fun(actions, action, errctx) do
    case Map.fetch(actions, action) do
      {:ok, %NimbleOptions{}} = found ->
        found

      :error ->
        {:error, {:unknown_action, {action, errctx}}}
    end
  end

  defp swap_variables(rdmx, params) do
    %{vars: vars} = rdmx

    swapped =
      Enum.map(params, fn
        {k, {:var, var}} -> {k, Readmix.Generator.expect_variable(vars, var)}
        {k, v} -> {k, v}
      end)

    {:ok, swapped}
  end

  defp validate_params(params, params_schema, errctx) do
    case NimbleOptions.validate(params, params_schema) do
      {:ok, _} = fine ->
        fine

      {:error, validation_error} ->
        {:error, {:params_validation_error, {validation_error, errctx}}}
    end
  end

  # {:ok, mod} -> {:ok, mod}
  # :error when ns == :rdmx -> {:ok, Readmix.Generators.BuiltIn}
  # :error -> {:error, {:unresolved_generator, ns}}
  # other -> raise "invalid resolver return value: #{inspect(other)}"
  defp call_transformer(rdmx, mod, action, params, previous_content) do
    context = %Context{previous_content: previous_content, readmix: rdmx}

    case mod.generate(action, params, context) do
      {:ok, iodata} -> {:ok, iodata}
      {:error, reason} -> {:error, {:generator_error, {mod, action, params, reason}}}
      other -> {:error, {:invalid_generator_return, {mod, action, params, other}}}
    end
  end

  def format_error(%Readmix.Parser.ParseError{} = e) do
    Readmix.Parser.ParseError.message(e)
  end

  def format_error(%Readmix.Error{} = e) do
    Readmix.Error.message(e)
  end

  defp convert_error(reason, %BlockSpec{} = block) do
    convert_error(reason, block.file, block.loc)
  end

  defp convert_error(reason, path) when is_binary(path) do
    convert_error(reason, path, nil)
  end

  defp convert_error(%Readmix.Error{} = e, _path, _loc) do
    e
  end

  defp convert_error(%Readmix.Parser.ParseError{} = e, _path, _loc) do
    e
  end

  defp convert_error(reason, path, loc) do
    Readmix.Error.convert(reason, path, loc)
  end

  @doc """
  Renders a block or a list of blocks as iodata without processing.
  """
  def content_to_iodata(%BlockSpec{} = block) do
    %{
      content: subs,
      raw_header: raw_header,
      raw_footer: raw_footer
    } = block

    [raw_header, content_to_iodata(subs), raw_footer]
  end

  def content_to_iodata([{:text, text} | blocks]) do
    [text | content_to_iodata(blocks)]
  end

  def content_to_iodata([{:generated, spec} | blocks]) do
    [content_to_iodata(spec) | content_to_iodata(blocks)]
  end

  def content_to_iodata([]) do
    []
  end
end
