defmodule Readmix.Context do
  import Readmix.Records

  @moduledoc """
  Helpers to access the context in generator actions.
  """

  defstruct previous_content: [], readmix: nil, siblings: {[], []}

  @doc """
  Returns a function that reads the given var from the given context.

  The returned function with throw `{:undef_var, key}` if the variable is not
  defined.
  """
  def getter(%__MODULE__{} = context, key) do
    fn -> expect_variable(context.readmix.vars, key) end
  end

  @doc false
  def expect_variable(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> throw({:undef_var, key})
    end
  end

  @doc """
  Returns a section from the current rendering context at the same nesting
  level.

  This function can only retrieve sections that are defined above the calling
  generated block. If multiple sections share the same name, it will return the
  closest section, _.i.e_ the last one in file order.
  """
  def lookup_rendered_section(%__MODULE__{} = context, section_name) do
    {previous, _} = context.siblings

    case List.keyfind(previous, section_name, generated(:section_name)) do
      generated(rendered: {_, _, _}) = section -> {:ok, section}
      nil -> {:error, {:section_not_found, section_name}}
    end
  end
end
