defmodule Readmix.Generators.BuiltIn.AppDep do
  alias Readmix.Context

  @moduledoc false

  def generate_app_dep(params, context) do
    otp_app = app_dep_otp_app(params, context)
    vsn = app_dep_vsn(params, otp_app)
    only = app_dep_only(params)
    runtime = app_dep_runtime(params)

    elems =
      [inspect(otp_app), vsn, only, runtime]
      |> Enum.reject(&is_nil/1)
      |> Enum.intersperse(", ")

    comma = if params[:comma] == false, do: "", else: ","

    snippet =
      """
      ```elixir
      def deps do
        [
          {#{elems}}#{comma}
        ]
      end
      ```
      """

    {:ok, snippet}
  end

  defp app_dep_otp_app(params, context) do
    case Keyword.get_lazy(params, :otp_app, Context.getter(context, :otp_app)) do
      app when is_atom(app) -> app
      app when is_binary(app) -> String.to_existing_atom(app)
    end
  end

  defp app_dep_vsn(params, otp_app) do
    vsn =
      Keyword.get_lazy(params, :vsn, fn ->
        otp_app
        |> Application.spec()
        |> Keyword.fetch!(:vsn)
        |> List.to_string()
      end)

    [?", "~> ", if(params[:patch], do: vsn, else: remove_vsn_patch(vsn)), ?"]
  end

  defp remove_vsn_patch(vsn) do
    vsn
    |> Version.parse!()
    |> Map.put(:patch, 9_999_999)
    |> Version.to_string()
    |> String.replace(~r/\.9999999.*/, "")
  end

  defp app_dep_only(params) do
    case params[:only] do
      nil ->
        nil

      "" ->
        nil

      envs ->
        atoms = envs |> String.split(",") |> Enum.map_intersperse(", ", &[?:, String.trim(&1)])
        ["only: [", atoms, "]"]
    end
  end

  defp app_dep_runtime(params) do
    case params[:runtime] do
      false -> ["runtime: false"]
      _ -> nil
    end
  end
end
