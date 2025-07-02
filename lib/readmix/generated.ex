defmodule Generated do
  @moduledoc """
  Struct representing a generated block in Readmix.
  """

  @enforce_keys [
    :mod,
    :action,
    :spec,
    :section_name,
    :params,
    :sub_blocks
  ]
  defstruct @enforce_keys ++ [:rendered]

  @type t :: %__MODULE__{
          mod: module() | nil,
          action: atom() | nil,
          params: keyword(),
          section_name: String.t() | nil,
          spec: Readmix.BlockSpec.t() | nil,
          sub_blocks: [term()],
          rendered: [term()]
        }
end
