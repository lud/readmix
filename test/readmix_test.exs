defmodule ReadmixTest do
  alias Readmix.Blocks.Generated
  alias Readmix.Blocks.Text
  alias Readmix.Context
  import Mox
  import Readmix.TestHelpers
  use ExUnit.Case

  doctest Readmix

  setup :verify_on_exit!

  defp test_new do
    test_new(resolver: fn _ -> :error end)
  end

  defp test_new(opts) do
    Readmix.new(opts)
  end

  defp transform_string!(rdmx, input) do
    case Readmix.transform_string(rdmx, input) do
      {:ok, output} -> output
      {:error, e} -> raise e
    end
  end

  describe "transforming content" do
    test "does not call anything for zero blocks" do
      blocks = []
      assert {:ok, []} = Readmix.blocks_to_iodata(test_new(), blocks)
    end

    test "does not call anything for raw_blocks" do
      blocks = [%Text{content: "hello"}]
      assert {:ok, iodata} = Readmix.blocks_to_iodata(test_new(), blocks)
      assert "hello" = IO.iodata_to_binary(iodata)
    end

    test "calls a registered module for a generator" do
      # Input block has no content
      input = """
      Before
      <!-- rdmx g:sometf a:1 b:2 -->
      Old Inside
      <!-- rdmx /g:sometf -->
      After
      """

      expected = """
      Before
      <!-- rdmx g:sometf a:1 b:2 -->
      New Inside
      <!-- rdmx /g:sometf -->
      After
      """

      mod =
        gen_mock()
        |> stub_actions([:sometf])
        |> expect(:generate, fn :sometf, [a: 1, b: 2], _ ->
          {:ok, ~c"New Inside\n"}
        end)

      assert expected == transform_string!(test_new(generators: %{g: mod}), input)
    end

    test "the rdmx namespace is always available" do
      # Input block has no content
      input = """
      <!-- rdmx :app_dep vsn:"99.99.99" -->
      <!-- rdmx /:app_dep -->
      """

      expected = """
      <!-- rdmx :app_dep vsn:"99.99.99" -->
      ```elixir
      def deps do
        [
          {:readmix, "~> 99.99"},
        ]
      end
      ```
      <!-- rdmx /:app_dep -->
      """

      # Here we pass a generators map, not mapping the rdmx namespace. But it
      # will still work.

      mod = stub_actions(gen_mock(), [])
      assert expected == transform_string!(test_new(generators: %{g: mod}), input)
    end

    test "passes a context to the generator" do
      input = """
      --before--

      <!-- rdmx g:sometf pos:1 some:foo -->
      Text One
      <!-- rdmx /g:sometf -->

      --between--

      <!-- rdmx g:sometf pos:2 some:bar -->
      Text Two
      <!-- rdmx /g:sometf -->

      --after--
      """

      mod =
        gen_mock()
        |> stub_actions([:sometf])
        |> expect(:generate, fn :sometf, [pos: 1, some: "foo"], context ->
          assert %Context{
                   siblings:
                     {[%Text{content: "--before--\n\n"}],
                      [
                        %Text{content: "\n--between--\n\n" <> _},
                        %Generated{
                          action: :sometf,
                          spec: %{generator: {_, _, [pos: 2, some: "bar"]}}
                        },
                        %Text{content: "\n--after--\n"}
                      ]},
                   previous_content: previous_content,
                   readmix: rdmx
                 } = context

          assert {:ok, iodata} = Readmix.blocks_to_iodata(rdmx, previous_content)
          assert "Text One\n" == IO.iodata_to_binary(iodata)

          {:ok, []}
        end)
        # Previous blocks are reversed
        |> expect(:generate, fn :sometf, [pos: 2, some: "bar"], context ->
          assert %Context{
                   siblings:
                     {[
                        %Text{content: "\n--between--\n\n"},
                        %Generated{
                          action: :sometf,
                          spec: %{generator: {_, _, [pos: 1, some: "foo"]}}
                        },
                        %Text{content: "--before--\n\n"}
                      ], [%Text{content: "\n--after--\n"}]},
                   previous_content: previous_content,
                   readmix: rdmx
                 } = context

          assert {:ok, iodata} = Readmix.blocks_to_iodata(rdmx, previous_content)
          assert "Text Two\n" == IO.iodata_to_binary(iodata)

          {:ok, []}
        end)

      _ = transform_string!(test_new(generators: %{g: mod}), input)
    end

    test "calls two different generators" do
      input = """
      Before
      <!-- rdmx g1:samesame -->
      Old Content
      <!-- rdmx /g1:samesame -->
      Middle
      <!-- rdmx g2:samesame -->
      Old Content
      <!-- rdmx /g2:samesame -->
      After
      """

      expected = """
      Before
      <!-- rdmx g1:samesame -->
      New Content from g1
      <!-- rdmx /g1:samesame -->
      Middle
      <!-- rdmx g2:samesame -->
      New Content from g2
      <!-- rdmx /g2:samesame -->
      After
      """

      mod1 =
        gen_mock()
        |> stub_actions([:samesame])
        |> expect(:generate, fn :samesame, [], _ ->
          {:ok, ~c"New Content from g1\n"}
        end)

      mod2 =
        gen_mock()
        |> stub_actions([:samesame])
        |> expect(:generate, fn :samesame, [], _ ->
          {:ok, ~c"New Content from g2\n"}
        end)

      assert {:ok, expected} ==
               Readmix.transform_string(test_new(generators: %{g1: mod1, g2: mod2}), input)
    end

    test "calls multiple actions on the same generator" do
      input = """
      Before
      <!-- rdmx g:action1 -->
      Old Content 1
      <!-- rdmx /g:action1 -->
      Middle
      <!-- rdmx g:action2 -->
      Old Content 2
      <!-- rdmx /g:action2 -->
      After
      """

      expected = """
      Before
      <!-- rdmx g:action1 -->
      New Content 1
      <!-- rdmx /g:action1 -->
      Middle
      <!-- rdmx g:action2 -->
      New Content 2
      <!-- rdmx /g:action2 -->
      After
      """

      mod =
        gen_mock()
        |> stub_actions([:action1, :action2])
        |> expect(:generate, fn :action1, [], _ ->
          {:ok, ~c"New Content 1\n"}
        end)
        |> expect(:generate, fn :action2, [], _ ->
          {:ok, ~c"New Content 2\n"}
        end)

      assert expected == transform_string!(test_new(generators: %{g: mod}), input)
    end

    test "variables values are given" do
      input = """
      Before
      <!-- rdmx g:sometf some_arg:$some_var -->
      Old Inside
      <!-- rdmx /g:sometf -->
      After
      """

      mod =
        gen_mock()
        |> stub_actions([:sometf])
        |> expect(:generate, fn :sometf, [some_arg: arg_value], _context ->
          assert 1234 == arg_value

          {:ok, []}
        end)

      rdmx = test_new(generators: %{g: mod}, vars: %{some_var: 1234})
      _ = transform_string!(rdmx, input)
    end

    test "section requires a name argument" do
      input = """
      <!-- rdmx rdmx:section -->
      Some content
      <!-- rdmx /rdmx:section -->
      """

      path = generate_file(input)

      assert {:error, %Readmix.Error{kind: :params_validation_error}} =
               Readmix.update_file(test_new(), path)
    end

    test "section processes nested blocks" do
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

    test "section leaves content unchanged if no nested blocks" do
      input = """
      <!-- rdmx rdmx:section name:my_section -->
      Some content without nested blocks
      <!-- rdmx /rdmx:section -->
      """

      expected = input

      assert expected == transform_string!(test_new(), input)
    end
  end

  describe "updating files" do
    test "creates a backup for tranfsormed files" do
      original_content = """
      this is a readme
      <!-- rdmx g:some_action -->
      Old Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(original_content)

      expected_out = """
      this is a readme
      <!-- rdmx g:some_action -->
      New Content
      <!-- rdmx /g:some_action -->
      """

      backup_dir = Briefly.create!(directory: true)

      mod =
        gen_mock()
        |> stub_actions([:some_action])
        |> expect(:generate, fn :some_action, [], _ -> {:ok, ~c"New Content\n"} end)

      backup_datetime = ~U[2027-06-05 04:03:02.0102Z]
      backup_stamp = "2027-06-05--04-03-02--0102"

      rdmx =
        Readmix.new(
          generators: %{g: mod},
          backup?: true,
          backup_dir: backup_dir,
          backup_datetime: backup_datetime
        )

      command_out =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = Readmix.update_file(rdmx, path)
        end)

      assert command_out =~ "Wrote backup"

      # The new file is updated with the new content
      assert expected_out == File.read!(path)

      # The old wile was created in the backup directory, in a
      # readmix-backup-<timestamp> subdirectory. And then a diretory path
      # mimicking the orignal path. In this test the orginal path is an absolute
      # one, in that case it should be appended fully

      "/" <> original_path_no_slash = path

      expected_backup_path =
        Path.join(backup_dir, "readmix/#{backup_stamp}/#{original_path_no_slash}")

      assert File.regular?(expected_backup_path)
      assert original_content == File.read!(expected_backup_path)
    end
  end

  describe "errors handling" do
    test "for parser error" do
      # Input with no end block
      input = """
      Before
      <!-- rdmx g:sometf -->
      Content without end tag
      """

      path = generate_file(input)

      # Run transformation to get the error
      assert {:error, %Readmix.Parser.ParseError{} = reason} =
               Readmix.update_file(test_new(), path)

      assert :no_block_end == reason.kind
      assert path == reason.file
      assert {2, _} = reason.loc

      # Check that format_error works
      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:2"
    end

    test "for another parse error" do
      # Input with invalid syntax
      input = """
      <!-- rdmx g:action invalid syntax -->
      Content
      <!-- rdmx /g:action -->
      """

      path = generate_file(input)

      assert {:error, %Readmix.Parser.ParseError{} = reason} =
               Readmix.update_file(test_new(), path)

      assert path == reason.file
      assert {1, _col} = reason.loc
      assert 1 == elem(reason.loc, 0)

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
    end

    test "for generator error" do
      # Input with unknown action
      input = """
      <!-- rdmx g:some_action a:1 -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod =
        gen_mock()
        |> stub_actions([:some_action])
        |> expect(:generate, fn _, _, _context -> {:error, :some_error} end)

      # Mock the resolver to return :error for any namespace
      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :generator_error == reason.kind
      assert {mod, :some_action, [a: 1], :some_error} == reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "some_action"
    end

    test "for unknown generator" do
      # Input with unresolved generator namespace
      input = """
      <!-- rdmx unresolved:action -->
      Content
      <!-- rdmx /unresolved:action -->
      """

      path = generate_file(input)

      assert {:error, %Readmix.Error{} = reason} = Readmix.update_file(test_new(), path)
      assert :unresolved_generator == reason.kind
      assert :unresolved == reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "unresolved"
    end

    test "for invalid generator return" do
      # Input with action that will return invalid format
      input = """
      <!-- rdmx g:bad_return -->
      Content
      <!-- rdmx /g:bad_return -->
      """

      path = generate_file(input)

      # Mock generator to return invalid format (not {:ok, _} or {:error, _})
      mod =
        gen_mock()
        |> stub_actions([:bad_return])
        |> expect(:generate, fn :bad_return, [], _context ->
          :not_a_valid_return_format
        end)

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :invalid_generator_return == reason.kind
      assert {mod, :bad_return, [], :not_a_valid_return_format} == reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "invalid generator return value"
    end

    test "for file read error" do
      # Use a non-existent file path
      path = "/non/existent/file.md"

      assert {:error, %Readmix.Error{} = reason} = Readmix.update_file(test_new(), path)
      assert :file_error == reason.kind
      assert :enoent = reason.arg
      assert path == reason.file

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ path
    end

    test "for undefined variable" do
      # Input with undefined variable
      input = """
      <!-- rdmx g:some_action arg:$some_variable -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod = stub_actions(gen_mock(), [:some_action])

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :undef_var == reason.kind
      assert :some_variable == reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "some_variable"
      assert formatted =~ "undefined variable"
    end

    test "for unknown action" do
      input = """
      <!-- rdmx g:some_action -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod = expect(gen_mock(), :actions, fn -> [] end)

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :unknown_action == reason.kind
      assert {:some_action, {:g, mod, :some_action}} == reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "unknown action"
      assert formatted =~ "some_action"
    end

    test "for unknown param" do
      input = """
      <!-- rdmx g:some_action some_arg:1 -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod =
        expect(gen_mock(), :actions, fn ->
          [some_action: [params: [other_param_not_required: [type: :string]]]]
        end)

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :params_validation_error == reason.kind
      assert {%NimbleOptions.ValidationError{}, {:g, ^mod, :some_action}} = reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "invalid params"
      assert formatted =~ "some_arg"
    end

    test "for invalid param type" do
      input = """
      <!-- rdmx g:some_action some_arg:1 -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod =
        expect(gen_mock(), :actions, fn ->
          [some_action: [params: [some_arg: [type: :string]]]]
        end)

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :params_validation_error == reason.kind
      assert {%NimbleOptions.ValidationError{}, {:g, ^mod, :some_action}} = reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "invalid params"
      assert formatted =~ "some_arg"
      assert formatted =~ "string"
    end

    test "for required param" do
      input = """
      <!-- rdmx g:some_action -->
      Content
      <!-- rdmx /g:some_action -->
      """

      path = generate_file(input)

      mod =
        expect(gen_mock(), :actions, fn ->
          [some_action: [params: [some_arg: [type: :string, required: true]]]]
        end)

      assert {:error, %Readmix.Error{} = reason} =
               Readmix.update_file(test_new(generators: %{g: mod}), path)

      assert :params_validation_error == reason.kind
      assert {%NimbleOptions.ValidationError{}, {:g, ^mod, :some_action}} = reason.arg
      assert path == reason.file
      assert {1, 11} == reason.loc

      formatted = Readmix.format_error(reason)
      assert is_binary(formatted)
      assert formatted =~ "#{path}:1"
      assert formatted =~ "invalid params"
      assert formatted =~ "some_arg"
      assert formatted =~ "required"
    end
  end

  describe "generators specs errors" do
    test "invalid nimble schemas in options" do
      mod =
        expect(gen_mock(), :actions, fn ->
          [some_action: [params: [some_arg: [type: :INVALID_NIMBLEOPTIONS_TYPE, required: true]]]]
        end)

      assert_raise ArgumentError, ~r/invalid action parameters for action :some_action/, fn ->
        Readmix.new(generators: %{g: mod})
      end
    end

    test "params should be optional" do
      input = """
      Before
      <!-- rdmx g:sometf -->
      Old Inside
      <!-- rdmx /g:sometf -->
      After
      """

      expected = """
      Before
      <!-- rdmx g:sometf -->
      New Inside
      <!-- rdmx /g:sometf -->
      After
      """

      # The mapped module does not export params in the action spec

      mod =
        gen_mock()
        |> expect(:actions, fn ->
          [sometf: []]
        end)
        |> expect(:generate, fn :sometf, [], _ ->
          {:ok, ~c"New Inside\n"}
        end)

      assert expected == transform_string!(test_new(generators: %{g: mod}), input)
    end
  end
end
