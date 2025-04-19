defmodule Readmix.Generators.BuiltIn.Section do
  @moduledoc false

  def generate_section(_params, context) do
    %{previous_content: prev, readmix: rdmx} = context
    Readmix.blocks_to_iodata(rdmx, prev)
  end
end
