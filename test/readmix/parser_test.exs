defmodule Readmix.ParserTest do
  alias Readmix.BlockSpec
  alias Readmix.Parser
  alias Readmix.Parser.ParseError
  use ExUnit.Case, async: true

  defp parse!(content) do
    assert {:ok, blocks} = Parser.parse_string(content, "test-string")
    blocks
  end

  defp error!(content) do
    assert {:error, %ParseError{} = e} = Parser.parse_string(content, "test-error")
    # check errmsg generation
    _ = ParseError.message(e)
    e
  end

  defmodule NoTransform do
    @behaviour Readmix.Generator

    @impl true
    def actions do
      [
        someblock: [params: [*: [type: :any]]],
        inner: [params: [*: [type: :any]]],
        outer: [params: [*: [type: :any]]]
      ]
    end

    @impl true
    def generate(_block_name, _params, context) do
      %{previous_content: prev, readmix: rdmx} = context
      Readmix.blocks_to_iodata(rdmx, prev)
    end
  end

  defp back_to_string(blocks, vars \\ %{}) do
    opts = [
      generators: %{rdmx: NoTransform},
      vars: vars
    ]

    rdmx = Readmix.new(opts)
    assert {:ok, iodata} = Readmix.blocks_to_iodata(rdmx, blocks)

    IO.iodata_to_binary(iodata)
  end

  describe "successful parsing" do
    test "should return raw and generated blocks" do
      content = """
      Some line before
      <!-- rdmx :someblock -->
        Some inner content
      <!-- rdmx /:someblock -->
      Some line after
      """

      # dump_text(content)

      blocks = parse!(content)

      assert [
               {:text, "Some line before\n"},
               {:generated,
                %{
                  # The newline is included in the header
                  raw_header: "<!-- rdmx :someblock -->\n",
                  # Generator without namespace uses the :rdmx namespace
                  generator: {:rdmx, :someblock, []},
                  # Newline is included in the footer too
                  raw_footer: "<!-- rdmx /:someblock -->\n",
                  # Content is given as blocks because it can contain nested
                  # blocks. The newline after the header is not present.
                  content: [
                    {:text, "  Some inner content\n"}
                  ]
                }},
               {:text, "Some line after\n"}
             ] = blocks

      assert content == back_to_string(blocks)
    end

    # defp dump_text(content) do
    #   lines = String.split(content, "\n")
    #   max_width = Enum.max(Enum.map(lines, &String.length/1))
    #   top_col_digits = for i <- 1..max_width, do: Integer.to_string(div(i, 10))
    #   bottom_col_digits = for i <- 1..max_width, do: Integer.to_string(rem(i, 10))

    #   left_pad =
    #     case length(lines) do
    #       n when n < 10 -> 1
    #       n when n < 100 -> 2
    #

    #   code_lines =
    #     lines
    #     |> Enum.with_index(1)
    #     |> Enum.map(fn {line, row} ->
    #       [String.pad_leading(Integer.to_string(row), left_pad), " ", line, ?\n]
    #     end)

    #   all_lines =
    #     [
    #       ?\n,
    #       [String.duplicate(" ", left_pad), " ", top_col_digits, ?\n],
    #       [String.duplicate(" ", left_pad), " ", bottom_col_digits, ?\n]
    #       | code_lines
    #     ]

    #   IO.puts(all_lines)
    # end

    test "blocks can have arguments" do
      content = """
      <!-- rdmx :someblock some_int: 1 some_float: 1.23 some_string: "hello:world" some_bool: true some_unquoted_string:hello -->
      Some content
      <!-- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator:
                   {:rdmx, :someblock,
                    some_int: 1,
                    some_float: 1.23,
                    some_string: "hello:world",
                    some_bool: true,
                    some_unquoted_string: "hello"},
                 raw_header:
                   "<!-- rdmx :someblock some_int: 1 some_float: 1.23 some_string: \"hello:world\" some_bool: true some_unquoted_string:hello -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "spacing is optional between arg key and value" do
      content = """
      <!-- rdmx :someblock some_int:1 some_float:1.23 some_string:"hello" some_bool:true -->
      Some content
      <!-- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator:
                   {:rdmx, :someblock,
                    some_int: 1, some_float: 1.23, some_string: "hello", some_bool: true},
                 raw_header:
                   "<!-- rdmx :someblock some_int:1 some_float:1.23 some_string:\"hello\" some_bool:true -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "arguments accept commas in between (comma is actually totally ignored)" do
      content = """
      <!-- rdmx :someblock,, a:1, b,:, ,,,2,, c: "i, love, commas," ,,,,-->
      Some content
      <!-- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, a: 1, b: 2, c: "i, love, commas,"},
                 raw_header: _,
                 raw_footer: _,
                 content: [_]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "blocks can use variables" do
      content = """
      <!-- rdmx :someblock some_var1:$var1 some_var2 ,,:,, $_var2,, -->
      Some content
      <!-- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator:
                   {:rdmx, :someblock,
                    [
                      some_var1: {:var, :var1},
                      some_var2: {:var, :_var2}
                    ]},
                 raw_header:
                   "<!-- rdmx :someblock some_var1:$var1 some_var2 ,,:,, $_var2,, -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks, %{var1: :some, _var2: :stuff})
    end

    test "block at the start of the file" do
      content = """
      <!-- rdmx :someblock -->
      Some content
      <!-- rdmx /:someblock -->
      Some after text
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               },
               text: "Some after text\n"
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "block with triple dashes" do
      content = """
      Some text before
      <!--- rdmx :someblock --->
      Some content
      <!--- rdmx /:someblock --->
      """

      blocks = parse!(content)

      assert [
               text: "Some text before\n",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!--- rdmx :someblock --->\n",
                 raw_footer: "<!--- rdmx /:someblock --->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "mixed double/triple dashes in same comment" do
      content = """
      Some text before
      <!-- rdmx :someblock --->
      Some content
      <!--- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               text: "Some text before\n",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock --->\n",
                 raw_footer: "<!--- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "mixed double/triple dashes in header/endr" do
      content = """
      Some text before
      <!-- rdmx :someblock -->
      Some content
      <!--- rdmx /:someblock --->
      """

      blocks = parse!(content)

      assert [
               text: "Some text before\n",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->\n",
                 raw_footer: "<!--- rdmx /:someblock --->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "in the middle of a line" do
      content = """
      Some text<!-- rdmx :someblock -->Some content<!-- rdmx /:someblock -->rest of line
      """

      blocks = parse!(content)

      assert [
               text: "Some text",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->",
                 raw_footer: "<!-- rdmx /:someblock -->",
                 content: [text: "Some content"]
               },
               text: "rest of line\n"
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "block a the end of the file" do
      content = """
      Some text before
      <!-- rdmx :someblock -->
      Some content
      <!-- rdmx /:someblock -->
      """

      blocks = parse!(content)

      assert [
               text: "Some text before\n",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "block a the end of the file without newline" do
      content = """
      Some text before
      <!-- rdmx :someblock -->
      Some content
      <!-- rdmx /:someblock -->\
      """

      blocks = parse!(content)

      assert [
               text: "Some text before\n",
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->",
                 content: [text: "Some content\n"]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end

    test "blocks will take one newline after the comment, no more" do
      content = """
      <!-- rdmx :someblock -->


      inner
      <!-- rdmx /:someblock -->


      bottom
      """

      # both "inner" and "bottom" content should be prefixed with two newlines,
      # and each comment header/footer followed by a single newline

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator: {:rdmx, :someblock, []},
                 raw_header: "<!-- rdmx :someblock -->\n",
                 raw_footer: "<!-- rdmx /:someblock -->\n",
                 content: [text: "\n\ninner\n"]
               },
               text: "\n\nbottom\n"
             ] = blocks

      assert content == back_to_string(blocks)
    end
  end

  describe "parse errors" do
    test "gibberish" do
      content = """
      <!-- rdmx hello how are you -->
      Some content
      <!-- /rdmx -->
      """

      # error is found at "how"
      assert %ParseError{kind: :syntax_error, loc: {1, 17}} = error!(content)
    end

    test "block without function" do
      content = """
      <!-- rdmx -->
      Some content
      <!-- /rdmx -->
      """

      # Here too error is after "rdmx "
      assert %ParseError{kind: :syntax_error, loc: {1, 11}} = error!(content)
    end

    test "parser does not support '-->' in arg string" do
      content = """
      <!-- rdmx :someblock some_string: "-->" -->
      Some content
      <!-- rdmx /:someblock -->
      """

      # The lexer tries to lex a quoted string but sees this:
      #
      #     :someblock some_string: "

      assert %Readmix.Parser.ParseError{
               loc: {1, 35},
               # The comment source stops in the string
               source: "<!-- rdmx :someblock some_string: \"-->"
             } =
               error!(content)
    end

    test "unended comment" do
      content = """
      <!-- rdmx :someblock
      Some content
      <!-- rdmx /:someblock -->
      """

      # It should fail with unterminated_comment_tag but because there is
      # another "-->" later it fails when lexing. in this case on the "<" char
      # of the second comment which is not a good symbol for the lexer.
      assert %Readmix.Parser.ParseError{
               arg: {:illegal, ~c"<"},
               loc: {3, 1}
             } = error!(content)
    end

    test "unended end comment" do
      content = """
      <!-- rdmx :someblock -->
      Some content
      <!-- rdmx /:someblock
      """

      # Here inforatunately it fails when lexing, in this case on the "<" char
      # of the next comment which is not a good symbol for the lexer.
      assert %Readmix.Parser.ParseError{
               loc: {3, _},
               kind: :unterminated_comment_tag
             } = error!(content)
    end

    test "unended block" do
      content = """
      some line
      <!-- rdmx :someblock -->
      Some content


      """

      # the error should be on line 2 and be about the block starting
      assert %Readmix.Parser.ParseError{
               loc: {2, 11},
               arg: nil,
               kind: :no_block_end,
               source: "<!-- rdmx :someblock -->\n"
             } = error!(content)
    end

    test "fail if params are provided on /closing block" do
      content = """
      <!-- rdmx :someblock -->
      Some content
      <!-- rdmx /:someblock arg: 1 -->
      """

      # Error column is not at the params level
      assert %Readmix.Parser.ParseError{
               loc: {3, _},
               kind: :illegal_block_end_params,
               source: "<!-- rdmx /:someblock arg: 1 -->\n"
             } = error!(content)
    end

    test "closing comment without starting comment" do
      content = """
      Some content
      <!-- rdmx /:someblock -->
      """

      assert %Readmix.Parser.ParseError{
               loc: {2, _},
               kind: :no_block_start,
               source: "<!-- rdmx /:someblock -->\n"
             } = error!(content)
    end
  end

  describe "nested blocks" do
    test "parser returns nested blocks as content" do
      content = """
      <!-- rdmx :outer -->
      Some content
      <!-- rdmx :inner -->
      Inner content
      <!-- rdmx /:inner -->
      More content
      <!-- rdmx /:outer -->
      """

      blocks = parse!(content)

      assert [
               generated: %BlockSpec{
                 generator: {:rdmx, :outer, []},
                 raw_header: "<!-- rdmx :outer -->\n",
                 raw_footer: "<!-- rdmx /:outer -->\n",
                 content: [
                   # Content contains built blocks too
                   text: "Some content\n",
                   generated: %BlockSpec{
                     generator: {:rdmx, :inner, []},
                     raw_header: "<!-- rdmx :inner -->\n",
                     raw_footer: "<!-- rdmx /:inner -->\n",
                     content: [text: "Inner content\n"]
                   },
                   text: "More content\n"
                 ]
               }
             ] = blocks

      assert content == back_to_string(blocks)
    end
  end
end
