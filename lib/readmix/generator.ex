defmodule Readmix.Generator do
  alias Readmix.BlockSpec
  alias Readmix.Context

  @moduledoc """
  Defines the behavior and utilities for Readmix generators.

  Generators are modules that implement this behaviour and provide actions that
  can be invoked from documents.

  To create a generator, use:

  ```elixir
  defmodule MyGenerator do
    use Readmix.Generator

    @doc "This action does something"
    action :my_action,
      as: :generate_my,
      params: [
        param1: [type: :string, doc: "Parameter documentation"]
      ]

    @moduledoc \"""
    My custom actions.

    \#{Readmix.Docs.generate()}
    \"""

    defp generate_my(params, context) do
      {:ok, "Generated content"}
    end
  end
  ```

  This is equivalent to the following:

  ```elixir
  defmodule MyGenerator do
    @behaviour Readmix.Generator

    @actions [
      my_action: [
        params: [
          param1: [type: :string, doc: "Parameter documentation"]
        ],
        doc: "This action does something"
      ]
    ]

    @moduledoc \"""
    My custom actions.

    \#{Readmix.Docs.generate(@actions)}
    \"""

    @impl true
    def actions, do: @actions

    @impl true
    def generate(:my_action, params, context) do
      generate_my(params, context)
    end

    defp generate_my(params, context) do
      {:ok, "Generated content"}
    end
  end
  ```
  """

  @type block_name :: atom
  @type params :: %{optional(binary) => integer | float | binary}
  @type block :: {:text, iodata} | {:generated, block_spec}

  @type block_spec :: BlockSpec.t()
  @type context :: %Context{:previous_content => [block], readmix: Readmix.t()}
  @type action_name :: atom
  @type action_spec_opt ::
          {:as, function_name :: atom} | {:params, NimbleOptions.schema()} | {:doc, String.t()}
  @type action_spec :: [action_spec_opt]

  @callback actions :: [{action_name, action_spec}]
  @callback generate(block_name, params, context) :: {:ok, iodata()} | {:error, term}

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :rdmx_action, accumulate: true)

      require Readmix.Docs

      import unquote(__MODULE__), only: [action: 2]

      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
    end
  end

  defmacro action(atom, spec) when is_atom(atom) and is_list(spec) do
    quote bind_quoted: binding() do
      attr_doc =
        case Module.delete_attribute(__MODULE__, :doc) do
          {_, doc} when is_binary(doc) -> doc
          doc when is_binary(doc) -> doc
          _ -> nil
        end

      @rdmx_action {atom, {spec, attr_doc}}
    end
  end

  defmacro __before_compile__(env) do
    case Module.get_attribute(env.module, :rdmx_action) do
      [] -> nil
      actions -> compile_callbacks(env, actions)
    end
  end

  defp compile_callbacks(env, actions) do
    env = Macro.escape(env)

    quote bind_quoted: binding() do
      # generate/3 header

      @impl true
      def generate(action, params, context)

      # dispatch generate to own actions

      Enum.each(actions, fn {action, {spec, doc}} ->
        impl_fun =
          case Keyword.fetch(spec, :as) do
            {:ok, fun} when is_atom(fun) -> fun
            :error -> action
          end

        def generate(unquote(action), params, context) do
          unquote(impl_fun)(params, context)
        end
      end)

      # export the known actions
      exported = Enum.map(actions, fn {action, {spec, _}} -> {action, spec} end)
      @impl true
      def actions, do: unquote(exported)
    end
  end
end
