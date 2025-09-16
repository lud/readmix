defmodule Readmix do
  alias Readmix.Blocks.Generated
  alias Readmix.Blocks.Text
  alias Readmix.BlockSpec
  alias Readmix.Context
  alias Readmix.Generators.BuiltIn
  alias Readmix.Scopes.Defaults

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

  You can configure Readmix with custom generators, variables, and scope
  modules:

  ```elixir
  Readmix.new(
    generators: %{my_namespace: MyGeneratorModule},
    vars: %{my_var: "hello"},
    env: [MyScope | Readmix.default_scopes()]
  )
  ```
  """

  defstruct [:resolver, :vars, :backup_fun]

  @type block :: Generated.t() | Text.t()

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

    # Unlike generators, the default scopes are not pulled if the configuration
    # is set.
    #
    # config_scopes() returns default_scopes() if the configuration is not set.
    scopes =
      case opts[:scopes] do
        nil -> Readmix.config_scopes()
        list when is_list(list) -> list
      end

    # Modules defined first in the list have precedence, subsequent modules do
    # not overwrite their vars. The external vars have precedence over all
    # modules.
    Enum.reduce(scopes, external_vars, fn mod, acc ->
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
  Returns the default scopes used for built-in generators.

  If you need to configure your own scopes but want to use default Readmix
  scopes as well, include these in the configuration:

      # config/dev.exs
      import Config

      config :readmix,
        scopes: [MyScope1, MyScope2 | Readmix.default_scopes()]
  """
  def default_scopes do
    [Readmix.Scopes.Defaults]
  end

  @doc false
  def config_scopes do
    Application.get_env(:readmix, :scopes, default_scopes())
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
    with {:ok, parsed} <- parse_string(string, opts[:source_path]),
         {:ok, blocks} <- preprocess_blocks(rdmx, parsed) do
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

  defp preprocess_blocks(rdmx, blocks) do
    result =
      Enum.reduce_while(blocks, {:ok, []}, fn block, {:ok, acc} ->
        case preprocess_block(rdmx, block) do
          {:ok, record} -> {:cont, {:ok, [record | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:ok, rev} -> {:ok, :lists.reverse(rev)}
      {:error, _} = err -> err
    end
  end

  defp preprocess_block(_rdmx, {:text, content}), do: {:ok, %Text{content: content}}

  defp preprocess_block(rdmx, {:spec, block_spec}) do
    %BlockSpec{
      generator: {ns, action, params},
      content: sub_parsed
    } = block_spec

    with {:ok, sub_blocks} <- preprocess_blocks(rdmx, sub_parsed),
         {:ok, {mod, params}} <- resolve_call(rdmx, ns, action, params) do
      {:ok,
       %Generated{
         mod: mod,
         action: action,
         params: params,
         section_name: section_name(mod, action, params),
         spec: block_spec,
         sub_blocks: sub_blocks
       }}
    else
      {:error, reason} ->
        {:error, convert_error(reason, block_spec)}
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
      {:ok, %NimbleOptions{}} = found -> found
      :error -> {:error, {:unknown_action, {action, errctx}}}
    end
  end

  defp swap_variables(rdmx, params) do
    %{vars: vars} = rdmx

    swapped =
      Enum.map(params, fn
        {k, {:var, var}} -> {k, Readmix.Context.expect_variable(vars, var)}
        {k, v} -> {k, v}
      end)

    {:ok, swapped}
  catch
    :throw, {:undef_var, _} = e -> {:error, e}
  end

  defp validate_params(params, params_schema, errctx) do
    case NimbleOptions.validate(params, params_schema) do
      {:ok, _} = fine ->
        fine

      {:error, validation_error} ->
        {:error, {:params_validation_error, {validation_error, errctx}}}
    end
  end

  defp section_name(BuiltIn, :section, args), do: Keyword.fetch!(args, :name)
  defp section_name(_, _, _), do: nil

  def blocks_to_iodata(rdmx, blocks) do
    blocks_to_iodata(rdmx, blocks, _rendered = [])
  end

  # We do not turn the blocks into iodata immediately, because some blocks may
  # want to find the content of previous blocks by matching on them. So we just
  # populate the :rendered key of the blocks and when all blocks are rendered we
  # can just reverse and assemble the binary.
  defp blocks_to_iodata(rdmx, [block | blocks], rendered) do
    case render_block(rdmx, block, _siblings = {rendered, blocks}) do
      {:ok, new_block} -> blocks_to_iodata(rdmx, blocks, [new_block | rendered])
      {:error, _} = err -> err
    end
  end

  defp blocks_to_iodata(_rdmx, [], rendered) do
    iodata =
      Enum.reduce(rendered, [], fn
        %Text{content: bin}, acc ->
          [bin | acc]

        %Generated{rendered: {header, content, footer}}, acc ->
          [header, content, footer | acc]
      end)

    {:ok, iodata}
  end

  defp render_block(_rdmx, %Text{} = text_block, _), do: {:ok, text_block}

  defp render_block(rdmx, %Generated{} = block, siblings) do
    %Generated{
      sub_blocks: sub_blocks,
      spec: %{raw_header: raw_header, raw_footer: raw_footer} = spec
    } = block

    try do
      case call_transformer(rdmx, block, siblings, sub_blocks) do
        {:ok, iodata} -> {:ok, %{block | rendered: {raw_header, iodata, raw_footer}}}
        {:error, reason} -> {:error, convert_error(reason, spec)}
      end
    catch
      :throw, {:undef_var, _} = e -> {:error, convert_error(e, spec)}
    end
  end

  defp call_transformer(rdmx, block, siblings, previous_content) do
    %Generated{mod: mod, action: action, params: params} = block

    context = %Context{
      readmix: rdmx,
      siblings: siblings,
      previous_content: previous_content,
      block: block
    }

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
end
