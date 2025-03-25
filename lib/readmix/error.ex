defmodule Readmix.Error do
  @moduledoc """
  A generic exception for Readmix errors.
  """

  @enforce_keys [:kind, :loc, :file, :arg]
  defexception @enforce_keys

  def message(%{kind: :generator_error} = e) do
    {mod, action, params, reason} = e.arg

    "generator error in #{file_loc(e)}, (#{inspect(mod)}, #{inspect(action)}, #{inspect(params)}), got: #{inspect(reason)}"
  end

  def message(%{kind: :unresolved_generator} = e) do
    "unknown generator namespace error in #{file_loc(e)}, no module registered for #{inspect(e.arg)}"
  end

  def message(%{kind: :invalid_generator_return} = e) do
    {mod, action, params, retval} = e.arg

    "invalid generator return value in #{file_loc(e)}, (#{inspect(mod)}, #{inspect(action)}, #{inspect(params)}), expected result tuple for iodata, got: #{inspect(retval)}"
  end

  def message(%{kind: :file_error} = e) do
    case e.arg do
      :eisdir -> "updating directories is not supported yet, tried to update #{e.file}"
      arg -> "file error when reading #{e.file}, got: #{inspect(arg)}"
    end
  end

  def message(%{kind: :undef_var} = e) do
    "undefined variable $#{e.arg} in #{file_loc(e)}"
  end

  def message(%{kind: :unknown_action} = e) do
    {action, {ns, mod, action}} = e.arg

    "unknown action #{ns}:#{action} in #{file_loc(e)} for module #{inspect(mod)}"
  end

  def message(%{kind: :params_validation_error} = e) do
    {nimble_error, {ns, mod, action}} = e.arg

    # THIS IS BAD
    nimble_message = String.replace(Exception.message(nimble_error), "option", "param")

    "invalid params for #{ns}:#{action} in #{file_loc(e)} for module #{inspect(mod)}, #{nimble_message}"
  end

  defp file_loc(e) do
    {line, col} = e.loc
    "#{e.file}:#{line}:#{col}"
  end

  @doc false
  def convert(reason, path, loc) do
    {kind, arg} =
      case reason do
        {:file_error, ^path, reason} ->
          {:file_error, reason}

        {:unresolved_generator, arg} ->
          {:unresolved_generator, arg}

        {:generator_error, {_mod, _action, _params, _reason}} = kind_arg ->
          kind_arg

        {:invalid_generator_return, {_mod, _action, _params, _retval}} = kind_arg ->
          kind_arg

        {:undef_var, _var} = kind_arg ->
          kind_arg

        {:unknown_action, {_ns, _errctx}} = kind_arg ->
          kind_arg

        {:params_validation_error, {%NimbleOptions.ValidationError{}, _}} = kind_arg ->
          kind_arg
      end

    %__MODULE__{kind: kind, arg: arg, file: path, loc: loc}
  end
end
