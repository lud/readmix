defmodule Mix.Tasks.Rdmx.Update do
  alias CliMate.CLI
  use Mix.Task

  @shortdoc "Updates blocks in a file or directory"

  @requirements ["app.config"]

  @command [
    module: __MODULE__,
    doc: "Regenerates the blocks in the given files.",
    arguments: [
      path: [
        required: true,
        repeat: false,
        type: :string,
        doc: """
        The file to update. Accepts multiple files.
        """
      ]
    ],
    options: [
      backup: [
        type: :boolean,
        short: :b,
        doc: "Perform a backup of the updated files.",
        default: true
      ],
      backup_dir: [
        type: :string,
        short: :d,
        doc: "Target directory to backup files before update.",
        default: &__MODULE__.default_opt/1,
        default_doc: "Defaults to `System.tmp_dir!()`."
      ],
      var: [
        type: :string,
        keep: true,
        doc: """
        Define variables for generators. Overrides variables defined from scopes.

        Variables must be given with a key and value:

              --var "some_key=some_value"
        """
      ]
    ]
  ]

  @moduledoc """
  Updates Readmix blocks in a file.

  A backup of updated files is automatically done in the system temporary
  directory.

  Readmix will use the default generators and scopes defined in the
  configuration for the `:readmix` application, under the `:generators` and
  `:scopes` keys:

  ```elixir
  # dev.exs

  config :readmix,
    generators: [MyGenerator],
    scopes: [MyScope, Readmix.Scopes.Defaults]
  ```

  #{CliMate.CLI.format_usage(@command, format: :moduledoc)}

  ## Examples

  ```bash
  # Update a single file
  mix rdmx.update README.md

  # Update with custom variables
  mix rdmx.update README.md --var "app_vsn=1.2.3"

  # Update without backup
  mix rdmx.update README.md --no-backup
  ```
  """

  @doc false
  def default_opt(:backup_dir), do: Readmix.default_backup_directory()

  @impl true
  def run(argv) do
    %{options: options, arguments: arguments} = CLI.parse_or_halt!(argv, @command)

    file = arguments.path

    variables =
      Map.new(options.var, fn var ->
        case String.split(var, "=", parts: 2) do
          ["" | _] -> CLI.halt_error("received a variable with empty key")
          [k, v] -> {String.to_atom(k), v}
        end
      end)

    rdmx = Readmix.new(backup?: options.backup, backup_dir: options.backup_dir, vars: variables)

    case Readmix.update_file(rdmx, file) do
      :ok -> CLI.success("Updated #{file}")
      {:error, reason} -> CLI.halt_error(Readmix.format_error(reason))
    end
  end
end
