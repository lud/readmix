defmodule Mix.Tasks.Rdmx.Update do
  alias CliMate.CLI
  use Mix.Task

  @shortdoc "Updates blocks in files"

  @requirements ["app.config"]

  @command [
    module: __MODULE__,
    doc: "Regenerates the blocks in the given files.",
    arguments: [
      path: [
        required: true,
        repeat: true,
        type: :string,
        doc: """
        The files to update.
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

  # Update multiple files
  mix rdmx.update README.md guides/*.md

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

    variables =
      Map.new(options.var, fn var ->
        case String.split(var, "=", parts: 2) do
          ["" | _] -> CLI.halt_error("received a variable with empty key")
          [k, v] -> {String.to_atom(k), v}
        end
      end)

    rdmx = Readmix.new(backup?: options.backup, backup_dir: options.backup_dir, vars: variables)

    results = Enum.map(arguments.path, &update_file(rdmx, &1))

    if Enum.any?(results, &(&1 == :error)) do
      CLI.halt(1)
    end
  end

  defp update_file(rdmx, file) do
    case Readmix.update_file(rdmx, file) do
      :ok ->
        CLI.success("Updated #{file}")
        :ok

      {:error, reason} ->
        CLI.error(Readmix.format_error(reason))
        :error
    end
  end
end
