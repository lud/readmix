defmodule Readmix.Scope do
  @moduledoc """
  Defines the scope behaviour for Readmix scopes.

  A scope is used to define variables used in Readmix blocks, such as:

  ```markdown
  <!-- rdmx :app_dep vsn:$my_custom_variable -->
  some content
  <!-- rdmx /:app_dep -->
  ```

  To define `$my_custom_variable`, a scope module could be defined like so:

  ```elixir
  defmodule MyScope do
    @behaviour Readmix.Env

    @impl true
    def get_vars do
      %{my_custom_variable: "1.2.3"}
    end
  end
  ```

  Scopes can be provided with the `:scopes` options for `Readmix.new/1`.
  """

  @type vars :: %{optional(atom) => term}

  @callback get_vars :: vars
end
