defmodule Readmix.Scopes.Defaults do
  @behaviour Readmix.Scope

  @moduledoc """
  This is the default Readmix scope that provides variables to generator
  actions.

  Every variable is defined as a function in this module. Refer to the functions
  documentation to see which variables are defined.

  These variables are derived from the current Mix project. When Readmix runs
  outside of a Mix project (for instance in a standalone script), the variables
  whose value cannot be determined are simply not defined.
  """

  @impl true
  def get_vars do
    %{}
    |> maybe_put(:otp_app, otp_app())
    |> maybe_put(:app_vsn, app_vsn())
  end

  @doc """
  The OTP application atom (example: `:readmix`) of the current application, or
  `nil` when running outside of a Mix project.
  """
  def otp_app do
    Keyword.get(Mix.Project.config(), :app)
  end

  @doc """
  The current application version from `mix.exs`, or `nil` when running outside
  of a Mix project.
  """
  def app_vsn do
    Keyword.get(Mix.Project.config(), :version)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
