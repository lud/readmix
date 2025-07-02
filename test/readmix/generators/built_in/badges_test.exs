defmodule Readmix.Generators.BuiltIn.BadgesTest do
  use ExUnit.Case, async: true

  defp test_new(opts \\ []) do
    Readmix.new(opts)
  end

  defp transform_string!(input) do
    transform_string!(test_new(), input)
  end

  defp transform_string!(rdmx, input) do
    case Readmix.transform_string(rdmx, input) do
      {:ok, output} -> output
      {:error, e} -> raise e
    end
  end

  describe "badges" do
    test "generate badges with custom URLs" do
      input = """
      <!-- rdmx :badges
        hexpm         : "someapp?color=4e2a8e"
        github_action : "someone/someapp/elixir.yaml?label=CI"
        license       : someapp
        -->

          some prev content

      <!-- rdmx /:badges -->
      """

      expected = """
      <!-- rdmx :badges
        hexpm         : "someapp?color=4e2a8e"
        github_action : "someone/someapp/elixir.yaml?label=CI"
        license       : someapp
        -->
      [![hex.pm Version](https://img.shields.io/hexpm/v/someapp?color=4e2a8e)](https://hex.pm/packages/someapp)
      [![Build Status](https://img.shields.io/github/actions/workflow/status/someone/someapp/elixir.yaml?label=CI)](https://github.com/someone/someapp/actions/workflows/elixir.yaml)
      [![License](https://img.shields.io/hexpm/l/someapp.svg)](https://hex.pm/packages/someapp)
      <!-- rdmx /:badges -->
      """

      assert expected == transform_string!(input)
    end

    test "generate badges with custom image alt texts" do
      input = """
      <!-- rdmx :badges
        hexpm         : "someapp?color=4e2a8e|SOME ALT 1"
        github_action : "someone/someapp/elixir.yaml?label=CI|SOME ALT 2"
        license       : "someapp|SOME ALT 3"
        -->

          some prev content

      <!-- rdmx /:badges -->
      """

      expected = """
      <!-- rdmx :badges
        hexpm         : "someapp?color=4e2a8e|SOME ALT 1"
        github_action : "someone/someapp/elixir.yaml?label=CI|SOME ALT 2"
        license       : "someapp|SOME ALT 3"
        -->
      [![SOME ALT 1](https://img.shields.io/hexpm/v/someapp?color=4e2a8e)](https://hex.pm/packages/someapp)
      [![SOME ALT 2](https://img.shields.io/github/actions/workflow/status/someone/someapp/elixir.yaml?label=CI)](https://github.com/someone/someapp/actions/workflows/elixir.yaml)
      [![SOME ALT 3](https://img.shields.io/hexpm/l/someapp.svg)](https://hex.pm/packages/someapp)
      <!-- rdmx /:badges -->
      """

      assert expected == transform_string!(input)
    end
  end
end
