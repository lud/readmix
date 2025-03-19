defmodule Readmix.Context do
  @moduledoc """
  Defines the context behaviour for Readmix contexts.

  A context is used to define variables used in Readmix blocks, such as:

  ```markdown
  <!-- rdmx :app_dep vsn:$my_custom_variable -->
  some content
  <!-- rdmx /:app_dep -->
  ```

  To define `$my_custom_variable`, a context module could be defined like so:

  ```elixir
  defmodule MyContext do
    @behaviour Readmix.Context

    @impl true
    def get_vars do
      %{my_custom_variable: "1.2.3"}
    end
  end
  ```

  Context can be provided with the `:contexts` options for `Readmix.new/1`.
  """

  defstruct previous_content: [], readmix: nil

  @type vars :: %{optional(atom) => term}

  @callback get_vars :: vars
end
