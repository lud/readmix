defmodule Readmix.Generators.BuiltIn.EvalTest do
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

  describe "bad arguments" do
    test "no args" do
      input = ~S"""
      <!-- rdmx rdmx:eval -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} =
               Readmix.transform_string(test_new(), input)
    end

    test "both section andcode" do
      input = ~S"""
      <!-- rdmx rdmx:eval section:foo code:foo -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} =
               Readmix.transform_string(test_new(), input)
    end
  end

  describe "section evaluation" do
    test "evaluates code from a section" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      a = 1 + 1
      "result: #{a}"
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      a = 1 + 1
      "result: #{a}"
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      ```elixir
      "result: 2"
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "section can contain text" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      Hello, this is some Elixir:
      ```elixir
      a = 1 + 1
      "result: #{a}"
      ```
      Nice!
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      Hello, this is some Elixir:
      ```elixir
      a = 1 + 1
      "result: #{a}"
      ```
      Nice!
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      ```elixir
      "result: 2"
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "displays exceptions errors" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      List.first(%{})
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code catch:true -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      List.first(%{})
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code catch:true -->
      ```
      ** (FunctionClauseError) no function clause matching in List.first/2
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "displays throws" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      throw {:some, "value"}
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code catch:true -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      throw {:some, "value"}
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code catch:true -->
      ```
      ** (throw) {:some, "value"}
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "fails on syntax errors" do
      # the catch:true argument should have no impact here
      #
      # parse error shoud be on line 5
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir


      {a, b,]



      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code catch:true -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{} = e} =
               Readmix.transform_string(test_new(), input, source_path: "testfile.txt")

      message = Exception.message(e)

      assert message =~ "testfile.txt:5"
    end

    test "uses inspect with sort maps" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      %{:b=>2, :a=>1}
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```elixir
      %{:b=>2, :a=>1}
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      ```elixir
      %{a: 1, b: 2}
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "requires referenced section to exist" do
      input = ~S"""
      <!-- rdmx rdmx:eval section:missing_section -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} = Readmix.transform_string(test_new(), input)
    end

    test "requires referenced section to contain a code block" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section -->
      Not a code block
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_section -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} = Readmix.transform_string(test_new(), input)
    end

    test "requires the elixir language on fences" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_code -->
      ```
      "Hello #{String.upcase("world")}"
      ```
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_code -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} = Readmix.transform_string(test_new(), input)
    end

    test "unfinished code bock" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section -->
      ```elixir
      a = 1
      <!-- rdmx /rdmx:section -->

      <!-- rdmx rdmx:eval section:my_section -->
      <!-- rdmx /rdmx:eval -->
      """

      assert {:error, %Readmix.Error{}} = Readmix.transform_string(test_new(), input)
    end
  end

  describe "raw evaluation" do
    test "evaluates a raw code expression" do
      input = ~S"""
      <!-- rdmx rdmx:eval code:"inspect(~c'hello', charlists: :as_lists)" -->
      <!-- rdmx /rdmx:eval -->
      """

      # We ask for inspect and that is a string, so the output has quotes when
      # dumping the value

      expected = ~S"""
      <!-- rdmx rdmx:eval code:"inspect(~c'hello', charlists: :as_lists)" -->
      ```elixir
      "[104, 101, 108, 108, 111]"
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "evaluates a raw code expression without fences" do
      input = ~S"""
      <!-- rdmx rdmx:eval code:"inspect(~c'hello', charlists: :as_lists)" as_text:true -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:eval code:"inspect(~c'hello', charlists: :as_lists)" as_text:true -->
      [104, 101, 108, 108, 111]
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "multiline code block" do
      input = ~S"""
      <!-- rdmx rdmx:eval code:"

      a = 1
      b = 2

      a + b

      " -->
      <!-- rdmx /rdmx:eval -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:eval code:"

      a = 1
      b = 2

      a + b

      " -->
      ```elixir
      3
      ```
      <!-- rdmx /rdmx:eval -->
      """

      assert expected == transform_string!(input)
    end

    test "as text without a string" do
      # self(), a pid, does not implement string chars
      input = ~S"""
      <!-- rdmx rdmx:eval code:"self()" as_text:true -->
      <!-- rdmx /rdmx:eval -->
      """

      assert_raise Readmix.Error, ~r{does not implement String.Chars}, fn ->
        transform_string!(input)
      end
    end
  end
end
