defmodule Readmix.Contexts.Defaults do
  @behaviour Readmix.Context

  @moduledoc """
  This is the default Readmix context for variables.

  Every variable is defined as a function in this module. Refer to the functions
  documentation to see which variables are defined.
  """

  @impl true
  def get_vars do
    %{otp_app: otp_app()}
  end

  @doc """
  Returns the OTP application atom (example: `:readmix`) of the current
  application.
  """
  def otp_app do
    Keyword.fetch!(Mix.Project.config(), :app)
  end
end
