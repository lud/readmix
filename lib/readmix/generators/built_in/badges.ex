defmodule Readmix.Generators.BuiltIn.Badges do
  @moduledoc false

  def generate_badges(params, _context) do
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
      |> URI.merge(path)
      |> URI.to_string()

    package_url =
      "https://hex.pm/packages/"
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
