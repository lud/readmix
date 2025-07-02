defmodule Readmix.Blocks.Text do
  @moduledoc """
  Struct representing a text block in Readmix.
  """

  defstruct [:content]

  @type t :: %__MODULE__{content: binary()}
end
