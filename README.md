# Readmix

<!-- rdmx :badges
    hexpm         : "readmix?color=4e2a8e"
    github_action : "lud/readmix/elixir.yaml?label=CI&branch=main"
    license       : readmix
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/readmix?color=4e2a8e)](https://hex.pm/packages/readmix)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/readmix/elixir.yaml?label=CI&branch=main)](https://github.com/lud/readmix/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/readmix.svg)](https://hex.pm/packages/readmix)
<!-- rdmx /:badges -->

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `readmix` to your list of dependencies in `mix.exs`:

<!-- rdmx :app_dep only:"dev,test" runtime:false vsn:$app_vsn -->
```elixir
def deps do
  [
    {:readmix, "~> 0.7", only: [:dev, :test], runtime: false},
  ]
end
```
<!-- rdmx /:app_dep -->

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/readmix>.

