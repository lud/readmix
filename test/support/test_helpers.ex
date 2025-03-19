defmodule Readmix.TestHelpers do
  @moduledoc false
  defmacro env_mod do
    line = __CALLER__.line
    {fun, _} = __CALLER__.function

    prefix =
      fun
      |> Atom.to_string()
      |> String.replace(" ", "_")
      |> Macro.camelize()
      |> List.wrap()

    rand = "L#{line}"

    Module.concat(prefix ++ [rand])
  end

  defmacro gen_mock do
    quote do
      defmock(env_mod(), for: Readmix.Generator)
    end
  end

  def stub_actions(mod, actions) when is_list(actions) do
    Mox.stub(mod, :actions, fn ->
      Enum.map(actions, fn
        :action ->
          raise "do not use :action as an action name for tests, it's confusing"

        action ->
          {action, [params: [*: [type: :any]]]}
      end)
    end)
  end

  @doc false
  def generate_dir(filemap) do
    dir = Briefly.create!(directory: true, prefix: "readmix-test-file")

    filemap
    |> flatten_filemap(dir, [])
    |> Enum.each(fn {path, contents} ->
      path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(path, contents)
    end)

    dir
  end

  def generate_file(content) do
    path = Briefly.create!(extname: ".md", prefix: "readmix-test-file")
    File.write!(path, content)

    path
  end

  defp flatten_filemap(filemap, dir, acc) when is_map(filemap) do
    Enum.reduce(filemap, acc, fn
      {path, contents}, acc when is_binary(contents) -> [{Path.join(dir, path), contents} | acc]
      {path, subs}, acc when is_map(subs) -> flatten_filemap(subs, Path.join(dir, path), acc)
    end)
  end
end
