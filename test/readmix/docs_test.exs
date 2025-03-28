defmodule Readmix.DocsTest do
  alias Readmix.Docs
  import Readmix.TestHelpers
  use ExUnit.Case, async: true

  doctest Readmix.Docs

  describe "section extraction" do
    test "returns the first section with the expected name" do
      path =
        generate_file("""

        # Ignored section with different name:

        <!-- rdmx :section name:OTHER_SECTION -->
        expected content
        <!-- rdmx /:section -->


        # Expected section:

        <!-- rdmx :section name:WANTED -->
        expected content
        <!-- rdmx /:section -->


        # Ignored section with the same name:

        <!-- rdmx :section name:WANTED -->
        other section with same name, ignored
        <!-- rdmx /:section -->
        """)

      assert "expected content\n" ==
               IO.iodata_to_binary(Docs.extract_section(path, "WANTED"))
    end

    test "sections can be nested" do
      # here we have two WANTED section, the first one in order of appearance is
      # nested. in this case a depth first search is done.

      path =
        generate_file("""
        <!-- rdmx :section name:PARENT -->

        content before

          <!-- rdmx :section name:WANTED -->
          inner content
          <!-- rdmx /:section -->

        content after
        <!-- rdmx /:section -->

        <!-- rdmx :section name:WANTED -->
        other section with same name, ignored
        <!-- rdmx /:section -->
        """)

      # note the indentation of the /end tag is part of the content
      assert "  inner content\n  " ==
               IO.iodata_to_binary(Docs.extract_section(path, "WANTED"))

      # We can also get the content of the parent
      expected_parent = """

      content before

        <!-- rdmx :section name:WANTED -->
        inner content
        <!-- rdmx /:section -->

      content after
      """

      assert expected_parent == IO.iodata_to_binary(Docs.extract_section(path, "PARENT"))
    end
  end
end
