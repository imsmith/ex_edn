defmodule EDN do
  @moduledoc """
  EDN (extensible data notation) reader and writer. See `decode/2` and
  `encode/1`. No runtime dependencies.

      iex> {:ok, %{a: 1, b: vector}} = EDN.decode("{:a 1, :b [1 2 3]}")
      iex> vector
      #EDN.Vector<[1, 2, 3]>

      iex> EDN.encode(%{a: 1})
      {:ok, "{:a 1}"}

  ## Types

  `value/0` is every term `decode/2` can return; the type mapping is in the
  README. Every public function carries a `@spec`, and the project compiles
  with `warnings_as_errors`, so a type violation the Elixir 1.20 checker
  infers from guards and patterns fails the build rather than warning.
  """

  alias EDN.Error

  @typedoc "A decoded EDN value. Vectors are `EDN.Vector.t/0` unless `vectors: :list`."
  @type value ::
          nil
          | boolean
          | integer
          | float
          | String.t()
          | atom
          | [value]
          | EDN.Vector.t()
          | %{optional(value) => value}
          | MapSet.t(value)
          | EDN.Symbol.t()
          | EDN.Character.t()
          | EDN.UUID.t()
          | EDN.Tag.t()
          | DateTime.t()
          | term

  @typedoc "Receives the decoded element of a tagged form; returns its replacement."
  @type handler :: (value -> term)

  @typedoc "Options accepted by `decode/2` and `decode!/2`."
  @type option ::
          {:handlers, %{String.t() => handler}}
          | {:keywords, :atom | :safe}
          | {:vectors, :vector | :list}
          | {:max_depth, pos_integer}

  @default_handlers %{"inst" => &EDN.Tag.inst/1, "uuid" => &EDN.Tag.uuid/1}

  @doc """
  Decodes EDN text. One top-level form returns its value; several return a
  list of values.

      iex> EDN.decode("1 2")
      {:ok, [1, 2]}

      iex> EDN.decode("[1 2]", vectors: :list)
      {:ok, [1, 2]}

      iex> EDN.decode("(1 2")
      {:error, %EDN.Error.UnbalancedDelimiter{message: "unclosed ( at line 1, column 1", line: 1, col: 1}}

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
  @spec decode(String.t(), [option]) :: {:ok, value} | {:error, Error.t()}
  def decode(input, opts \\ []) do
    {:ok, decode!(input, opts)}
  rescue
    e -> to_error(e, __STACKTRACE__)
  end

  @doc """
  Like `decode/2`, but returns the value and raises `EDN.Error.*` on failure.

      iex> EDN.decode!(~S(\#{:a 1}))
      MapSet.new([1, :a])
  """
  @spec decode!(String.t(), [option]) :: value
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

      iex> EDN.encode([1, :a, EDN.Vector.from_list([2])])
      {:ok, "(1, :a, [2])"}

      iex> {:error, %Protocol.UndefinedError{}} = EDN.encode({:tuple})

  Supports `nil`, booleans, atoms (as keywords), binaries, integers, floats,
  lists (as EDN lists), maps, `MapSet`, `DateTime` (as `#inst`), the structs
  in this package, and any other struct (as a map). Tuples, pids and the like
  return `{:error, %Protocol.UndefinedError{}}`; malformed package structs return
  `{:error, %ArgumentError{}}`, or `{:error, %EDN.Error.InvalidTagValue{}}` for a
  `#uuid` or `#inst` the default handlers would refuse.
  """
  @spec encode(term) ::
          {:ok, String.t()}
          | {:error, Protocol.UndefinedError.t() | ArgumentError.t() | Error.InvalidTagValue.t()}
  def encode(term) do
    {:ok, encode!(term)}
  rescue
    e in [Protocol.UndefinedError, ArgumentError, Error.InvalidTagValue] -> {:error, e}
  end

  @doc """
  Like `encode/1`, but returns the string and raises on failure.

      iex> EDN.encode!(~U[1985-04-12 23:20:50Z])
      ~s(#inst "1985-04-12T23:20:50Z")
  """
  @spec encode!(term) :: String.t()
  def encode!(term), do: EDN.Encode.encode(term)

  # A bad option is a caller bug, not bad input: raise rather than return {:error, _}.
  @spec option!(keyword, atom, value, (term -> boolean)) :: value when value: term
  defp option!(opts, key, default, valid?) do
    value = Keyword.get(opts, key, default)

    if valid?.(value),
      do: value,
      else: raise(ArgumentError, "invalid #{inspect(key)} option: #{inspect(value)}")
  end

  @spec to_error(Exception.t(), Exception.stacktrace()) :: {:error, Error.t()} | no_return
  defp to_error(%{__struct__: module} = e, stacktrace) do
    if module in Error.all(), do: {:error, e}, else: reraise(e, stacktrace)
  end
end
