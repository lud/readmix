defmodule Readmix.Docs do
  @moduledoc """
  Utilities for generating documentation for Readmix generators.
  """

  @doc """
  Generates documentation for the actions registered with
  `Readmix.Generator.action/2`.
  """
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

  @doc """
  Generates documentation for actions defined as a keyword list.
  """
  def generate(actions) do
    [
      "### Actions\n\n"
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
      ["#### ", Atom.to_string(action), ?\n],
      doc,
      ["##### Parameters ", ?\n],
      params
    ]
  end
end
