defprotocol EDN.Encode do
  @moduledoc """
  Turns a term into EDN text. Implement it for your own structs to control
  their representation; structs without an implementation encode as maps.

      iex> EDN.Encode.encode([1, :a, "s"])
      ~s[(1, :a, "s")]

  Implementations raise `ArgumentError` for a package struct whose fields
  cannot be written as EDN, and `Protocol.UndefinedError` for non-EDN terms.
  """
  @fallback_to_any true

  @doc """
  Encodes `term` as EDN text.

      iex> EDN.Encode.encode(%EDN.Symbol{name: "a/b"})
      "a/b"
  """
  @spec encode(t) :: String.t()
  def encode(term)
end

defmodule EDN.Encode.Util do
  @moduledoc false

  @spec join(Enumerable.t(), String.t(), String.t()) :: String.t()
  def join(items, open, close),
    do: open <> Enum.map_join(items, ", ", &EDN.Encode.encode/1) <> close

  @spec escape(String.t()) :: String.t()
  def escape(string) do
    for <<c <- string>>, into: "" do
      case c do
        ?" -> ~S(\")
        ?\\ -> ~S(\\)
        ?\n -> ~S(\n)
        ?\r -> ~S(\r)
        ?\t -> ~S(\t)
        c -> <<c>>
      end
    end
  end

  # Mirrors the decoder's symbol grammar so we never emit text we cannot read back.
  @spec name!(term) :: String.t()
  def name!(name) when is_binary(name) do
    if name == "/" or
         (Enum.all?(String.split(name, "/"), &part?/1) and length(String.split(name, "/")) <= 2),
       do: name,
       else: raise(ArgumentError, "not a valid EDN name: #{inspect(name)}")
  end

  def name!(name), do: raise(ArgumentError, "not a valid EDN name: #{inspect(name)}")

  defp part?(part),
    do:
      Regex.match?(
        ~r/\A(?:[\p{L}*!_?$%&=<>]|[-+.](?![0-9]))[\p{L}\p{N}.*+!\-_?$%&=<>:#]*\z/u,
        part
      )
end

defimpl EDN.Encode, for: Atom do
  def encode(atom) when atom in [nil, true, false], do: Atom.to_string(atom)
  def encode(:/), do: raise(ArgumentError, "not a valid EDN keyword: :/")
  def encode(atom), do: ":" <> EDN.Encode.Util.name!(Atom.to_string(atom))
end

defimpl EDN.Encode, for: BitString do
  def encode(string) when is_binary(string) do
    if String.valid?(string),
      do: ~s(") <> EDN.Encode.Util.escape(string) <> ~s("),
      else: raise(ArgumentError, "binary is not valid UTF-8: #{inspect(string)}")
  end

  def encode(bits),
    do: raise(Protocol.UndefinedError, protocol: EDN.Encode, value: bits)
end

defimpl EDN.Encode, for: Integer do
  def encode(int), do: Integer.to_string(int)
end

defimpl EDN.Encode, for: Float do
  def encode(float), do: Float.to_string(float)
end

defimpl EDN.Encode, for: List do
  def encode(list), do: EDN.Encode.Util.join(list, "(", ")")
end

defimpl EDN.Encode, for: Map do
  def encode(map) do
    "{" <>
      Enum.map_join(map, ", ", fn {k, v} ->
        EDN.Encode.encode(k) <> " " <> EDN.Encode.encode(v)
      end) <> "}"
  end
end

defimpl EDN.Encode, for: MapSet do
  def encode(set), do: EDN.Encode.Util.join(set, "\#{", "}")
end

defimpl EDN.Encode, for: DateTime do
  def encode(datetime), do: ~s(#inst ") <> DateTime.to_iso8601(datetime) <> ~s(")
end

defimpl EDN.Encode, for: EDN.Vector do
  def encode(vector), do: EDN.Encode.Util.join(EDN.Vector.to_list(vector), "[", "]")
end

defimpl EDN.Encode, for: EDN.Symbol do
  def encode(%{name: name}), do: EDN.Encode.Util.name!(name)
end

defimpl EDN.Encode, for: EDN.Character do
  def encode(%{char: "\n"}), do: "\\newline"
  def encode(%{char: "\r"}), do: "\\return"
  def encode(%{char: " "}), do: "\\space"
  def encode(%{char: "\t"}), do: "\\tab"
  # A comma is whitespace to the reader, so it cannot follow a backslash.
  def encode(%{char: ","}), do: "\\u002C"

  def encode(%{char: char}) when is_binary(char) do
    if String.valid?(char) and String.length(char) == 1,
      do: "\\" <> char,
      else: raise(ArgumentError, "not a single EDN character: #{inspect(char)}")
  end

  def encode(%{char: char}),
    do: raise(ArgumentError, "not a single EDN character: #{inspect(char)}")
end

defimpl EDN.Encode, for: EDN.UUID do
  def encode(%{value: value}) do
    EDN.Tag.uuid(value)
    "#uuid " <> EDN.Encode.encode(value)
  end
end

defimpl EDN.Encode, for: EDN.Tag do
  def encode(%{name: name, value: value}) do
    # Refuse built-in tags with values the default handlers cannot read back.
    case name do
      "inst" -> EDN.Tag.inst(value)
      "uuid" -> EDN.Tag.uuid(value)
      _ -> :ok
    end

    "#" <> EDN.Encode.Util.name!(name) <> " " <> EDN.Encode.encode(value)
  end
end

defimpl EDN.Encode, for: Any do
  def encode(%{__struct__: _} = struct), do: EDN.Encode.encode(Map.from_struct(struct))

  def encode(term),
    do: raise(Protocol.UndefinedError, protocol: EDN.Encode, value: term)
end
