defmodule Readmix.Generators.BuiltInTest do
  use ExUnit.Case, async: true

  describe "app_dep" do
    @current_vsn Keyword.fetch!(Mix.Project.config(), :version)
    @current_version Version.parse!(@current_vsn)

    defp current_vsn(:minor) do
      %Version{@current_version | patch: 11_001_100}
      |> Version.to_string()
      |> String.replace(".11001100", "")
    end

    defp current_vsn(:full) do
      @current_vsn
    end

    def tapout({:ok, iodata}) do
      {:ok, tapout(iodata)}
    end

    def tapout(iodata) do
      IO.puts(iodata)
      iodata
    end

    defp test_new do
      Readmix.new([])
    end

    defp transform_string!(input) do
      case Readmix.transform_string(test_new(), input) do
        {:ok, output} -> output
        {:error, e} -> raise e
      end
    end

    test "returns the current otp_app and current version" do
      input = """
      <!-- rdmx :app_dep -->
      <!-- rdmx /:app_dep -->
      """

      expected =
        """
        <!-- rdmx :app_dep -->
        ```elixir
        def deps do
          [
            {:readmix, "~> #{current_vsn(:minor)}"},
          ]
        end
        ```
        <!-- rdmx /:app_dep -->
        """

      assert expected == transform_string!(input)
    end

    test "remove comma and include patch" do
      input = """
      <!-- rdmx :app_dep comma:false patch:true -->
      <!-- rdmx /:app_dep -->
      """

      expected =
        """
        <!-- rdmx :app_dep comma:false patch:true -->
        ```elixir
        def deps do
          [
            {:readmix, "~> #{current_vsn(:full)}"}
          ]
        end
        ```
        <!-- rdmx /:app_dep -->
        """

      assert expected == transform_string!(input)
    end

    test "provide vsn from arg" do
      input = """
      <!-- rdmx :app_dep vsn:"1.2.3" -->
      <!-- rdmx /:app_dep -->
      """

      expected =
        """
        <!-- rdmx :app_dep vsn:"1.2.3" -->
        ```elixir
        def deps do
          [
            {:readmix, "~> 1.2"},
          ]
        end
        ```
        <!-- rdmx /:app_dep -->
        """

      assert expected == transform_string!(input)
    end

    test "otp_app can also be changed" do
      input = """
      <!-- rdmx :app_dep otp_app:mox vsn:"3.3.3" -->
      <!-- rdmx /:app_dep -->
      """

      expected =
        """
        <!-- rdmx :app_dep otp_app:mox vsn:"3.3.3" -->
        ```elixir
        def deps do
          [
            {:mox, "~> 3.3"},
          ]
        end
        ```
        <!-- rdmx /:app_dep -->
        """

      assert expected == transform_string!(input)
    end

    test "supports the 'only' and 'runtime' options " do
      input = """
      <!-- rdmx :app_dep only:"dev,test" runtime:false -->
      <!-- rdmx /:app_dep -->
      """

      expected =
        """
        <!-- rdmx :app_dep only:"dev,test" runtime:false -->
        ```elixir
        def deps do
          [
            {:readmix, "~> #{current_vsn(:minor)}", only: [:dev, :test], runtime: false},
          ]
        end
        ```
        <!-- rdmx /:app_dep -->
        """

      assert expected == transform_string!(input)
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
