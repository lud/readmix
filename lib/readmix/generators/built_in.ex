defmodule Readmix.Generators.BuiltIn do
  alias Readmix.Generators.BuiltIn.AppDep
  alias Readmix.Generators.BuiltIn.Badges
  alias Readmix.Generators.BuiltIn.Eval
  alias Readmix.Generators.BuiltIn.Section
  use Readmix.Generator

  @doc """
  Generates a fenced code block for the `deps` function in `mix.exs`, pulling a
  package from hex.pm.
  """
  action :app_dep,
    as: :generate_app_dep,
    params: [
      otp_app: [
        type: :string,
        doc:
          "The OTP application to use in the dependency tuple. Defaults to the current application."
      ],
      vsn: [
        type: :string,
        doc: "The version number to use. Defaults to the current version of the OTP application."
      ],
      comma: [type: :boolean, default: true, doc: "Include a comma after the dependency tuple."],
      patch: [
        type: :boolean,
        default: false,
        doc: "Include the patch in the version number in the dependency tuple."
      ],
      only: [
        type: :string,
        doc:
          "Adds the `:only` option to the dependency tuple. Multiple environments can be separated with commas."
      ],
      runtime: [
        type: :boolean,
        doc: "When `false`, adds the `runtime: false` option to the dependency tuple."
      ]
    ]

  @doc """
  Generates badges with `img.shields.io`.

  Badges are generated in the order of the action params.
  """
  action :badges,
    as: :generate_badges,
    params: [
      hexpm: [
        type: :string,
        doc: """
        Generates a badge linking to [hex.pm](https://hex.pm/).

        Requires a package name and an optional query string for customization.

        Example: `"readmix?color=4e2a8e"`.
        """
      ],
      github_action: [
        type: :string,
        doc: """
        Generates a badge linking to the latest Github Action.

        Requires a package name and an optional query string for customization
        and limiting to a branch name.

        Example: `"lud/readmix/elixir.yaml?label=CI&branch=main"`.
        """
      ],
      license: [
        type: :string,
        doc: """
        Generates a badge linking to a license for an _Elixir_ package.

        Requires an hex.pm package name.

        Example: `"readmix"`.
        """
      ]
    ]

  @doc """
  Defines a named block that other generator actions can retrieve during
  generation.

  The section itself doesn't transform content but allows nested blocks to be
  processed.

  Note that uniqueness of names is not enforced.
  """
  action :section,
    as: :generate_section,
    params: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the section."
      ]
    ]

  @doc """
  Evaluates a fenced code block from the last section with the given name at the
  same nesting level and outputs the result of the evaluation in a fenced code
  block.

  ### Example

  ~~~markdown
  <!-- rdmx :section name:example -->
  ```elixir
  map = %{hello: "World"}
  Map.fetch!(map, :hello)
  ```
  <!-- rdmx /:section -->

  <!-- rdmx :eval section:example -->
  ```elixir
  "World"
  ```
  <!-- rdmx /:eval -->
  ~~~

  """
  action :eval,
    as: :eval_section,
    params: [
      section: [type: :string, required: true, doc: "The name of the section to evaluate."],
      catch: [
        type: :boolean,
        default: false,
        doc: "Allow errors and display exception banners as output in case of error."
      ]
    ]

  @moduledoc """
  Implements the built-in generators for Readmix.

  #{Readmix.Docs.generate()}
  """

  @doc false
  defdelegate generate_app_dep(params, context), to: AppDep

  @doc false
  defdelegate generate_badges(params, context), to: Badges

  @doc false
  defdelegate generate_section(params, context), to: Section

  @doc false
  defdelegate eval_section(params, context), to: Eval
end
