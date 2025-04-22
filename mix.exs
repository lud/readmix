defmodule Readmix.MixProject do
  use Mix.Project
  @source_url "https://github.com/lud/readmix"

  def project do
    [
      app: :readmix,
      version: "0.4.1",
      description: "A tool to generate parts of documentation with custom generator functions.",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      compilers: [:leex, :yecc | Mix.compilers()],
      leex_options: [error_location: :column, verbose: true, deterministic: true],
      yecc_options: [verbose: true, deterministic: true],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      versioning: versioning()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # App
      {:cli_mate, "~> 0.7", runtime: false},
      {:nimble_options, "~> 1.0"},

      # Dev, Test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37.3", only: :dev},
      {:mox, "~> 1.2", only: :test},
      {:briefly, "~> 0.5.1", only: :test},
      {:dialyxir, "~> 1.4", only: :test, runtime: false},
      {:ex_check, "~> 0.16.0", only: [:dev, :test]},
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:mix_version, "~> 2.4", only: [:dev, :test], runtime: false},
      {:modkit, "~> 0.6", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Github" => @source_url,
        "Changelog" => "https://github.com/lud/jsv/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    []
  end

  def cli do
    [preferred_envs: [dialyzer: :test]]
  end

  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling, :unknown, :extra_return],
      list_unused_filters: true,
      plt_add_deps: :app_tree,
      plt_add_apps: [:ex_unit, :mix, :cli_mate],
      plt_local_path: "_build/plts"
    ]
  end

  defp versioning do
    [
      annotate: true,
      before_commit: [
        &update_readme/1,
        {:add, "README.md"},
        &gen_changelog/1,
        {:add, "CHANGELOG.md"}
      ]
    ]
  end

  def update_readme(vsn) do
    :ok = Readmix.update_file(Readmix.new(vars: %{app_vsn: vsn}), "README.md")
  end

  defp gen_changelog(vsn) do
    case System.cmd("git", ["cliff", "--tag", vsn, "-o", "CHANGELOG.md"], stderr_to_stdout: true) do
      {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
      {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
    end
  end
end
