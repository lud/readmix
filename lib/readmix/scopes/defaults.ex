defmodule Readmix.Scopes.Defaults do
  @behaviour Readmix.Scope

  @moduledoc """
  This is the default Readmix scope that provides variables to generator
  actions.

  Every variable is defined as a function in this module. Refer to the functions
  documentation to see which variables are defined.
  """

  @impl true
  def get_vars do
    %{
      otp_app: otp_app(),
      app_vsn: app_vsn()
    }
  end

  @doc """
  The OTP application atom (example: `:readmix`) of the current application.
  """
  def otp_app do
    Keyword.fetch!(Mix.Project.config(), :app)
  end

  @doc """
  The current application version from `mix.exs`.
  """
  def app_vsn do
    Keyword.fetch!(Mix.Project.config(), :version)
  end
end
