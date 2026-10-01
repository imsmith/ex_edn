defmodule EDN.SpecTest do
  @moduledoc "Examples taken from edn.md, plus inputs real files contain."
  use ExUnit.Case, async: true
  alias EDN.{Vector, Symbol, Character, Tag, Error}

  defp d(s, opts \\ []), do: EDN.decode!(s, opts)
  defp sym(n), do: %Symbol{name: n}

  test "map example" do
    assert d(~S({:a 1, "foo" :bar, [1 2 3] four})) ==
             %{:a => 1, "foo" => :bar, Vector.from_list([1, 2, 3]) => sym("four")}
  end

  test "set example" do
    assert d(~S(#{a b [1 2 3]})) ==
             MapSet.new([sym("a"), sym("b"), Vector.from_list([1, 2, 3])])
  end

  test "discard example" do
    assert d("[a b #_foo 42]") == Vector.from_list([sym("a"), sym("b"), 42])
  end

  test "tag example" do
    assert d(~S(#myapp/Person {:first "Fred" :last "Mertz"})) ==
             %Tag{name: "myapp/Person", value: %{first: "Fred", last: "Mertz"}}
  end

  test "#inst and #uuid examples, equal when they designate the same value" do
    assert d(~S(#inst "1985-04-12T23:20:50.52Z")) == ~U[1985-04-12 23:20:50.52Z]
    assert d(~S(#inst "1985-04-12T23:20:50.52Z")) == d(~S(#inst "1985-04-12T21:20:50.52-02:00"))

    assert %EDN.UUID{value: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"} ==
             d(~S(#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"))
  end

  test "symbol and keyword rules from the spec" do
    assert d("my-namespace/foo") == sym("my-namespace/foo")
    assert d(":my/fred") == :"my/fred"

    assert d("(- + . -a +a .a)") ==
             Enum.map(~w(- + . -a +a .a), &sym/1)

    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("-1a")
  end

  test "characters, lists, nil, booleans" do
    assert d("(\\c \\newline \\space nil true false)") ==
             [
               %Character{char: "c"},
               %Character{char: "\n"},
               %Character{char: " "},
               nil,
               true,
               false
             ]
  end

  test "unicode in symbols, keywords and strings" do
    assert d(":café") == :café
    assert d("naïve") == sym("naïve")
    assert d(~s("日本語")) == "日本語"
  end

  # --- the calls the existing consumers make ---------------------------------------

  test "wagger-style: decode a vector and take its list" do
    assert {:ok, vec} = EDN.decode("[1 2 3]")
    assert Vector.to_list(vec) == [1, 2, 3]
  end

  test "llmagent-style: encode a map holding vectors, atoms and ISO datetimes" do
    out =
      EDN.encode!(%{
        event: :register,
        kinds: Vector.from_list([:a, :b]),
        at: "2026-10-01T00:00:00Z"
      })

    assert d(out) == %{
             event: :register,
             kinds: Vector.from_list([:a, :b]),
             at: "2026-10-01T00:00:00Z"
           }
  end
end
