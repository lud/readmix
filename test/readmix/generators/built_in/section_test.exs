defmodule Readmix.Generators.BuiltIn.SectionTest do
  import Mox
  import Readmix.TestHelpers
  use ExUnit.Case, async: true

  defp test_new(opts \\ []) do
    Readmix.new(opts)
  end

  defp transform_string!(rdmx, input) do
    case Readmix.transform_string(rdmx, input, source_file: "testfile.txt") do
      {:ok, output} -> output
      {:error, e} -> raise e
    end
  end

  describe "section name and nesting" do
    test "requires a name argument" do
      input = """
      <!-- rdmx rdmx:section -->
      Some content
      <!-- rdmx /rdmx:section -->
      """

      assert {:error, %Readmix.Error{kind: :params_validation_error} = e} =
               Readmix.transform_string(test_new(), input)

      assert Exception.message(e) =~ "required :name param not found"
    end

    test "does not accept extra arguments" do
      # This is to ensure that we can mach on the keyword list when
      # preprocessing the blocks.
      input = """
      <!-- rdmx rdmx:section name:stuff format:true other:123 -->
      Some content
      <!-- rdmx /rdmx:section -->
      """

      assert {:error, %Readmix.Error{kind: :params_validation_error} = e} =
               Readmix.transform_string(test_new(), input)

      assert Exception.message(e) =~ "unknown params [:other]"
    end

    test "processes nested blocks" do
      input = """
      <!-- rdmx rdmx:section name:my_section -->
      Before
      <!-- rdmx g:sometf -->
      Old Content
      <!-- rdmx /g:sometf -->
      After
      <!-- rdmx /rdmx:section -->
      """

      expected = """
      <!-- rdmx rdmx:section name:my_section -->
      Before
      <!-- rdmx g:sometf -->
      New Content
      <!-- rdmx /g:sometf -->
      After
      <!-- rdmx /rdmx:section -->
      """

      mod =
        gen_mock()
        |> stub_actions([:sometf])
        |> expect(:generate, fn :sometf, [], _ ->
          {:ok, ~c"New Content\n"}
        end)

      assert expected == transform_string!(test_new(generators: %{g: mod}), input)
    end

    test "leaves content unchanged if no nested blocks" do
      input = """
      <!-- rdmx rdmx:section name:my_section -->
      Some content without nested blocks
      <!-- rdmx /rdmx:section -->
      """

      expected = input

      assert expected == transform_string!(test_new(), input)
    end
  end

  describe "code formatting utilities" do
    test "formats elixir code blocks when format:true is specified" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      ```elixir
      def     hello(name),        do:      "Hello, #{name}!"
      ```
      <!-- rdmx /rdmx:section -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      ```elixir
      def hello(name), do: "Hello, #{name}!"
      ```
      <!-- rdmx /rdmx:section -->
      """

      assert expected == transform_string!(test_new(), input)
    end

    test "invalid elixir code is not formatted but emits a warning" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      ```elixir
      def(a]]
      ```
      <!-- rdmx /rdmx:section -->
      """

      out =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          assert input == transform_string!(test_new(), input)
        end)

      assert out =~ "mismatched delimiter found on nofile:3:6"
    end

    test "comments are preserved" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      ```elixir
      # This returns :bar most of the time
      def foo do
      case Enum.random(1..1000) do
      # maybe we should use 2 here. 2 is better than 1!
      1 -> :qux
      _ -> :bar
      end
      end
      ```
      <!-- rdmx /rdmx:section -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      ```elixir
      # This returns :bar most of the time
      def foo do
        case Enum.random(1..1000) do
          # maybe we should use 2 here. 2 is better than 1!
          1 -> :qux
          _ -> :bar
        end
      end
      ```
      <!-- rdmx /rdmx:section -->
      """

      assert expected == transform_string!(test_new(), input)
    end

    test "formats multiple elixir code blocks when format:true is specified" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      First block:
      ```elixir
      def add(a,b),do: a+b
      ```

      Second block:
      ```elixir
      def multiply(x,y) when is_number(x)and is_number(y),do: x*y
      ```
      <!-- rdmx /rdmx:section -->
      """

      expected = ~S"""
      <!-- rdmx rdmx:section name:my_section format:true -->
      First block:
      ```elixir
      def add(a, b), do: a + b
      ```

      Second block:
      ```elixir
      def multiply(x, y) when is_number(x) and is_number(y), do: x * y
      ```
      <!-- rdmx /rdmx:section -->
      """

      assert expected == transform_string!(test_new(), input)
    end

    if :gt == Version.compare(Version.parse!(System.version()), Version.parse!("1.18.0")) do
      test "migrates the code" do
        input = ~S"""
        <!-- rdmx rdmx:section name:my_section format:true -->
        ```elixir
        def bitstring_modifiers do
          <<foo::integer(), bar::custom_type>>
        end

        def charlist_sigils do
          'hello'
        end

        def no_unless do
          unless foo(), do: bar()
        end
        ```
        <!-- rdmx /rdmx:section -->
        """

        expected = ~S"""
        <!-- rdmx rdmx:section name:my_section format:true -->
        ```elixir
        def bitstring_modifiers do
          <<foo::integer, bar::custom_type()>>
        end

        def charlist_sigils do
          ~c"hello"
        end

        def no_unless do
          if !foo(), do: bar()
        end
        ```
        <!-- rdmx /rdmx:section -->
        """

        assert expected == transform_string!(test_new(), input)
      end
    end

    test "explicitly disables formatting when format:false is specified" do
      input = ~S"""
      <!-- rdmx rdmx:section name:my_section format:false -->
      ```elixir
      def        hello(name),do:            "Hello, #{name}!"
      ```
      <!-- rdmx /rdmx:section -->
      """

      expected = input

      assert expected == transform_string!(test_new(), input)
    end

    test "validates format parameter accepts only boolean values" do
      input = """
      <!-- rdmx rdmx:section name:my_section format:invalid -->
      Some content
      <!-- rdmx /rdmx:section -->
      """

      assert {:error, %Readmix.Error{kind: :params_validation_error} = e} =
               Readmix.transform_string(test_new(), input)

      assert Exception.message(e) =~ "format"
    end
  end
end
