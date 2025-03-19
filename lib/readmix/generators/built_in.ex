defmodule Readmix.Generators.BuiltIn do
  use Readmix.Generator

  @doc """
  Generates a fenced code block for the `deps` function in `mix.exs`, pulling a
  package from hex.pm.
  """
  action :app_dep,
    as: :generate_app_dep,
    params: [
      otp_app: [
        type: :string,
        doc:
          "The OTP application to use in the dependency tuple. Defaults to the current application."
      ],
      vsn: [
        type: :string,
        doc: "The version number to use. Defaults to the current version of the OTP application."
      ],
      comma: [type: :boolean, default: true, doc: "Include a comma after the dependency tuple."],
      patch: [
        type: :boolean,
        default: false,
        doc: "Include the patch in the version number in the dependency tuple."
      ],
      only: [
        type: :string,
        doc:
          "Adds the `:only` option to the dependency tuple. Multiple environments can be separated with commas."
      ],
      runtime: [
        type: :boolean,
        doc: "When `false`, adds the `runtime: false` option to the dependency tuple."
      ]
    ]

  @doc """
  Generates badges with `img.shields.io`.

  Badges are generated in the order of the action params.
  """
  action :badges,
    as: :generate_badges,
    params: [
      hexpm: [
        type: :string,
        doc: """
        Generates a badge linking to [hex.pm](https://hex.pm/).

        Requires a package name and an optional query string for customization.

        Example: `"readmix?color=4e2a8e"`.
        """
      ],
      github_action: [
        type: :string,
        doc: """
        Generates a badge linking to the latest Github Action.

        Requires a package name and an optional query string for customization
        and limiting to a branch name.

        Example: `"lud/readmix/elixir.yaml?label=CI&branch=main"`.
        """
      ],
      license: [
        type: :string,
        doc: """
        Generates a badge linking to a license for an _Elixir_ package.

        Requires an hex.pm package name.

        Example: `"readmix"`.
        """
      ]
    ]

  @moduledoc """
  Implements the built-in generators for Readmix.

  #{Readmix.Docs.generate()}
  """

  defp generate_app_dep(params, context) do
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
    case get_arg(params, :otp_app, or_var(context, :otp_app)) do
      app when is_atom(app) -> app
      app when is_binary(app) -> String.to_existing_atom(app)
    end
  end

  defp app_dep_vsn(params, otp_app) do
    vsn =
      get_arg(params, :vsn, fn ->
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

  defp generate_badges(params, _context) do
    badges =
      Enum.flat_map(params, fn
        {k, v} when k in [:hexpm, :github_action, :license] -> [gen_badge(k, v)]
        _ -> []
      end)

    {:ok, Enum.map(badges, &[&1, ?\n])}
  end

  # accepts package, package with ?<query_string>, and "|Image al" suffix
  defp gen_badge(:hexpm, arg) do
    {path, img_alt} = split_badge_img_alt(arg, "hex.pm Version")

    img_url =
      "https://img.shields.io/hexpm/v/"
      |> URI.parse()
      |> URI.merge(path)
      |> URI.to_string()

    package_url =
      "https://hex.pm/packages/"
      |> URI.parse()
      |> URI.merge(path)
      |> Map.merge(%{query: nil, fragment: nil})
      |> URI.to_string()

    markdown_badge(img_alt, img_url, package_url)
  end

  defp gen_badge(:github_action, arg) do
    {arg, img_alt} = split_badge_img_alt(arg, "Build Status")

    # TODO validate format
    [owner, repo, workflow] = String.split(arg, "/", parts: 3)

    img_url =
      "https://img.shields.io/github/actions/workflow/status/#{owner}/#{repo}/#{workflow}"

    workflow_query =
      with %{query: query} when is_binary(query) <- URI.parse(img_url),
           %{"branch" => branch} when branch != "" <- URI.decode_query(query) do
        URI.encode_query(query: "branch:#{branch}")
      else
        _ -> nil
      end

    workflow_url =
      "https://github.com/#{owner}/#{repo}/actions/workflows/#{workflow}"
      |> URI.parse()
      |> Map.merge(%{query: workflow_query, fragment: nil})
      |> URI.to_string()

    markdown_badge(img_alt, img_url, workflow_url)
  end

  defp gen_badge(:license, arg) do
    {hexpm_package, img_alt} = split_badge_img_alt(arg, "License")
    img_url = "https://img.shields.io/hexpm/l/#{hexpm_package}.svg"
    package_link = "https://hex.pm/packages/#{hexpm_package}"
    markdown_badge(img_alt, img_url, package_link)
  end

  defp split_badge_img_alt(arg, default_alt) do
    case String.split(arg, "|", parts: 2) do
      [single] -> {single, default_alt}
      [value, label] -> {value, label}
    end
  end

  defp markdown_badge(img_alt, img_url, link_url) do
    "[![#{img_alt}](#{img_url})](#{link_url})"
  end
end
