defmodule Readmix.Docs do
  @moduledoc """
  Utilities for generating documentation for Readmix generators.
  """

  @doc ~S'''
  Generates documentation for the actions registered with
  `Readmix.Generator.action/2`.

  ### Example

  ```elixir
  defmodule MyGenerator do
    use Readmix.Generator

    action :greeting, params [name: :string, required: true]

    @moduledoc """
    A block generator

    #{Readmix.Docs.generate()}
    """

    def greeting(args, _) do
      {:ok, ["hello ", args[:name]]}
    end
  end
  ```
  '''
  defmacro generate do
    quote do
      @rdmx_action
      |> :lists.reverse()
      |> Enum.map(fn {action, {spec, doc_attr}} ->
        doc =
          case Keyword.fetch(spec, :doc) do
            {:ok, doc} when is_binary(doc) and doc != "" -> doc
            _ -> doc_attr
          end

        {action, Keyword.put(spec, :doc, doc)}
      end)
      |> Readmix.Docs.generate()
    end
  end

  @doc ~S'''
  Generates documentation for actions defined as a keyword list.

  ```elixir
  defmodule MyGenerator do
    @behaviour Readmix.Generator

    @actions [
      greeting: [
        params [name: :string, required: true]
      ]
    ]

    @moduledoc """
    A block generator

    #{Readmix.Docs.generate(@actions)}
    """

    @impl true
    def actions, do: @actions

    @impl true
    def generate(:greeting, args, _) do
      {:ok, ["hello ", args[:name]]}
    end
  end
  ```
  '''
  def generate(actions) do
    [
      "## Readmix Actions\n\n"
      | Enum.map(actions, &format_action_doc/1)
    ]
  end

  defp format_action_doc({action, spec}) do
    doc =
      case spec[:doc] do
        nil -> []
        doc -> [doc, ?\n, ?\n]
      end

    params =
      spec
      |> Keyword.fetch!(:params)
      |> NimbleOptions.Docs.generate([])

    [
      ["### ", Atom.to_string(action), ?\n],
      doc,
      ["#### Parameters ", ?\n],
      params
    ]
  end

  @doc ~S'''
  Returns the content of a `rdmx:section` block from the given path.

  The content is returned as iodata for inclusion in documentation and not as
  Readmix blocks for transformation. The blocks are not processed, the _current_
  content of the file is returned.

  If you are using this function during compilation, it is recommended to
  declare the source file as an external resource.

  ### Example

  ```markdown
  <!-- rdmx :section name="examples" -->
  Here is how to use the awesome service...
  <!-- rdmx /:section -->
  ```

  ```elixir
  defmodule AwesomeService do
    @external_resource "guides/services/awesome.md"

    @moduledoc """
    This is an awesome service.

    ### Examples

    #{Readmix.Docs.extract_section("guides/services/awesome.md", "examples")}
    """
  end
  ```
  '''
  def extract_section(path, name) do
    path
    |> File.read!()
    |> Readmix.Parser.parse_string(path)
    |> case do
      {:error, e} ->
        raise e

      {:ok, blocks} ->
        case do_extract_section(blocks, name) do
          nil -> raise ArgumentError, "section #{inspect(name)} could not be found in #{path}"
          iodata -> iodata
        end
    end
  end

  defp do_extract_section([{:text, _} | blocks], name) do
    do_extract_section(blocks, name)
  end

  defp do_extract_section([{:generated, block} | blocks], name) do
    # we can match on the keyword list because :name is the only
    # required/allowed parameter.
    case block do
      %Readmix.BlockSpec{generator: {:rdmx, :section, [name: ^name]}, content: subs} ->
        Readmix.content_to_iodata(subs)

      %Readmix.BlockSpec{content: subs} ->
        case do_extract_section(subs, name) do
          nil -> do_extract_section(blocks, name)
          found -> found
        end
    end
  end

  defp do_extract_section([], _name) do
    nil
  end
end
