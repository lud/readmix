defmodule Readmix.BlockSpec do
  @moduledoc """
  Defines the structure for generated blocks found in documents.
  """

  alias Readmix.Generator

  @enforce_keys [:generator, :content, :raw_header, :raw_footer, :file, :loc]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          generator: {atom, atom, keyword},
          content: [Generator.block()],
          raw_header: String.t(),
          raw_footer: String.t(),
          file: String.t(),
          loc: nil | {pos_integer() | pos_integer()}
        }
end
