defmodule EDN do
  @moduledoc """
  EDN (extensible data notation) reader and writer. See `decode/2` and
  `encode/1`. No runtime dependencies.
  """

  alias EDN.Error

  @default_handlers %{"inst" => &EDN.Tag.inst/1, "uuid" => &EDN.Tag.uuid/1}

  @doc """
  Decodes EDN text. One top-level form returns its value; several return a
  list of values.

  ## Options

    * `:handlers` - `%{"my/tag" => fun}`; `fun` receives the decoded tagged
      element. Merged over the default `inst` and `uuid` handlers.
    * `:keywords` - `:atom` (default, `String.to_atom/1`) or `:safe`
      (`String.to_existing_atom/1`). Use `:safe` on untrusted input: atoms are
      never garbage collected.
    * `:vectors` - `:vector` (default, `%EDN.Vector{}`) or `:list`.
    * `:max_depth` - maximum nesting depth, default 512.

  An invalid option value raises `ArgumentError`: it is a caller bug, not bad input.
  """
  @spec decode(String.t(), keyword) :: {:ok, term} | {:error, Exception.t()}
  def decode(input, opts \\ []) do
    {:ok, decode!(input, opts)}
  rescue
    e -> to_error(e, __STACKTRACE__)
  end

  @doc "Like `decode/2`, but returns the value and raises `EDN.Error.*` on failure."
  @spec decode!(String.t(), keyword) :: term
  def decode!(input, opts \\ []) when is_binary(input) do
    handlers =
      option!(opts, :handlers, %{}, fn h ->
        is_map(h) and Enum.all?(h, fn {k, f} -> is_binary(k) and is_function(f, 1) end)
      end)

    opts = [
      handlers: Map.merge(@default_handlers, handlers),
      keywords: option!(opts, :keywords, :atom, &(&1 in [:atom, :safe])),
      vectors: option!(opts, :vectors, :vector, &(&1 in [:vector, :list])),
      max_depth: option!(opts, :max_depth, 512, &(is_integer(&1) and &1 > 0))
    ]

    case EDN.Decoder.forms(input, opts) do
      [] -> raise Error.EmptyInput, message: "no EDN forms in input"
      [form] -> form
      forms -> forms
    end
  end

  @doc """
  Encodes a term as EDN text. Elements are separated by `", "`.

  Supports `nil`, booleans, atoms (as keywords), binaries, integers, floats,
  lists (as EDN lists), maps, `MapSet`, `DateTime` (as `#inst`), the structs
  in this package, and any other struct (as a map). Tuples, pids and the like
  return `{:error, %Protocol.UndefinedError{}}`; malformed package structs return
  `{:error, %ArgumentError{}}`, or `{:error, %EDN.Error.InvalidTagValue{}}` for a
  `#uuid` or `#inst` the default handlers would refuse.
  """
  @spec encode(term) :: {:ok, String.t()} | {:error, Exception.t()}
  def encode(term) do
    {:ok, encode!(term)}
  rescue
    e in [Protocol.UndefinedError, ArgumentError, Error.InvalidTagValue] -> {:error, e}
  end

  @doc "Like `encode/1`, but returns the string and raises on failure."
  @spec encode!(term) :: String.t()
  def encode!(term), do: EDN.Encode.encode(term)

  # A bad option is a caller bug, not bad input: raise rather than return {:error, _}.
  defp option!(opts, key, default, valid?) do
    value = Keyword.get(opts, key, default)

    if valid?.(value),
      do: value,
      else: raise(ArgumentError, "invalid #{inspect(key)} option: #{inspect(value)}")
  end

  defp to_error(%{__struct__: module} = e, stacktrace) do
    if module in Error.all(), do: {:error, e}, else: reraise(e, stacktrace)
  end
end
