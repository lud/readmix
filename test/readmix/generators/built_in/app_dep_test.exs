defmodule Readmix.Generators.BuiltIn.AppDepTest do
  use ExUnit.Case, async: true

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

  describe "app_dep" do
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
end
