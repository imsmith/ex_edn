defmodule EDN.EncodeTest do
  use ExUnit.Case, async: true
  alias EDN.{Vector, Symbol, Character, UUID, Tag}

  defp e(term), do: EDN.encode!(term)

  test "scalars" do
    assert e(nil) == "nil"
    assert e(true) == "true"
    assert e(false) == "false"
    assert e(42) == "42"
    assert e(-7) == "-7"
    assert e(1.5) == "1.5"
    assert e(1.0e20) == "1.0e20"
    assert e(:a) == ":a"
    assert e(:"my/fred") == ":my/fred"
    assert e("hi") == ~s("hi")
  end

  test "strings are escaped" do
    assert e("a\"b\\c\nd\re\tf") == ~S("a\"b\\c\nd\re\tf")
    assert e("é") == ~s("é")
  end

  test "collections use ', ' separators" do
    assert e([1, 2]) == "(1, 2)"
    assert e([]) == "()"
    assert e(%{}) == "{}"
    assert e(%{a: 1}) == "{:a 1}"
    # map order is unspecified in EDN; compare as a set of entries
    assert e(%{a: 1, b: 2, c: 3})
           |> String.trim("{")
           |> String.trim("}")
           |> String.split(", ")
           |> Enum.sort() ==
             [":a 1", ":b 2", ":c 3"]

    assert e(MapSet.new([1])) == ~S"#{1}"
    assert e(MapSet.new()) == ~S"#{}"
    assert e(Vector.from_list([1, [2]])) == "[1, (2)]"
  end

  test "package types" do
    assert e(%Symbol{name: "my-ns/foo"}) == "my-ns/foo"
    assert e(%Character{char: "a"}) == "\\a"
    assert e(%Character{char: "\n"}) == "\\newline"
    assert e(%Character{char: " "}) == "\\space"

    assert e(%Tag{name: "myapp/Person", value: %{first: "Fred"}}) ==
             ~S(#myapp/Person {:first "Fred"})

    id = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
    assert e(%UUID{value: id}) == ~s(#uuid "#{id}")
  end

  test "DateTime encodes as #inst" do
    assert e(~U[1985-04-12 23:20:50.52Z]) == ~S(#inst "1985-04-12T23:20:50.52Z")
  end

  defmodule Point do
    defstruct [:x, :y]
  end

  test "other structs encode as maps" do
    assert e(%Point{x: 1, y: 2}) == "{:x 1, :y 2}"
  end

  test "unsupported terms return an error, never invalid EDN" do
    assert {:error, %Protocol.UndefinedError{}} = EDN.encode({:a, 1})
    assert {:error, %Protocol.UndefinedError{}} = EDN.encode([1, self()])
    assert {:error, %Protocol.UndefinedError{}} = EDN.encode(<<1::3>>)
    assert {:error, %ArgumentError{}} = EDN.encode(:"has space")
    assert {:error, %ArgumentError{}} = EDN.encode(%Symbol{name: "1abc"})
    assert_raise Protocol.UndefinedError, fn -> EDN.encode!({:a, 1}) end
  end

  test "round trip: decode(encode(x)) == x" do
    id = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"

    terms = [
      nil,
      true,
      false,
      0,
      -5,
      123_456_789_012_345_678_901,
      1.5,
      -2.0e-10,
      :a,
      :"ns/name",
      "plain",
      "q\"uote\\ \n\t\r",
      "ünïcode ✓",
      [],
      [1, [2, 3]],
      %{},
      %{"k" => [nil], a: 1},
      MapSet.new([1, :a, "s"]),
      Vector.from_list([1, Vector.from_list([]), %{a: 1}]),
      %Symbol{name: "foo"},
      %Symbol{name: "/"},
      %Character{char: "x"},
      %Character{char: "\n"},
      %Character{char: "("},
      %UUID{value: id},
      ~U[2020-01-02 03:04:05Z],
      %Tag{name: "myapp/thing", value: [1, 2]},
      %{%Symbol{name: "k"} => Vector.from_list([MapSet.new([1])])}
    ]

    for term <- terms do
      assert EDN.decode!(e(term)) == term, "round trip failed for #{inspect(term)}"
    end
  end

  test "non-UTF-8 binaries are rejected on encode rather than emitted" do
    assert {:error, %ArgumentError{}} = EDN.encode(<<0xFF>>)
  end

  test "charlists encode as lists of integers" do
    assert EDN.encode!(~c"ab") == "(97, 98)"
  end

  test "the bare symbol / is not a keyword, so :/ is refused rather than emitted" do
    assert {:error, %ArgumentError{}} = EDN.encode(:/)
    assert EDN.encode!(%Symbol{name: "/"}) == "/"
  end

  test "a comma character is written as \\u002C so the decoder can read it back" do
    assert e(%Character{char: ","}) == "\\u002C"
    assert EDN.decode!(e(%Character{char: ","})) == %Character{char: ","}
  end

  test "malformed Character structs are errors, never text the decoder rejects" do
    for bad <- ["ab", "", "newline", 5, nil] do
      assert {:error, %ArgumentError{}} = EDN.encode(%Character{char: bad}), inspect(bad)
    end
  end

  test "malformed Symbol, UUID and built-in Tag structs return errors from encode/1" do
    assert {:error, %ArgumentError{}} = EDN.encode(%Symbol{name: nil})
    assert {:error, %ArgumentError{}} = EDN.encode(%Tag{name: nil, value: 1})
    assert {:error, %EDN.Error.InvalidTagValue{}} = EDN.encode(%UUID{value: "nope"})
    assert {:error, %EDN.Error.InvalidTagValue{}} = EDN.encode(%UUID{value: nil})
    assert {:error, %EDN.Error.InvalidTagValue{}} = EDN.encode(%Tag{name: "inst", value: 5})
    assert {:error, %EDN.Error.InvalidTagValue{}} = EDN.encode(%Tag{name: "uuid", value: "nope"})
    assert {:ok, _} = EDN.encode(%Tag{name: "inst", value: "2020-01-01T00:00:00Z"})
  end
end
