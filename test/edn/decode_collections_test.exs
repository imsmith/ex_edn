defmodule EDN.DecodeCollectionsTest do
  use ExUnit.Case, async: true
  alias EDN.{Vector, Symbol, Tag, UUID, Error}

  defp d(s, opts \\ []), do: EDN.decode!(s, opts)

  test "lists, vectors, maps, sets" do
    assert d("()") == []
    assert d("(1 :a \"x\")") == [1, :a, "x"]
    assert d("[]") == Vector.from_list([])
    assert d("[1 [2 3] (4)]") == Vector.from_list([1, Vector.from_list([2, 3]), [4]])
    assert d("{}") == %{}

    assert d("{:a 1, \"foo\" :bar, [1 2 3] four}") ==
             %{:a => 1, "foo" => :bar, Vector.from_list([1, 2, 3]) => %Symbol{name: "four"}}

    assert d(~S"#{}") == MapSet.new()
    assert d(~S"#{a [1 2 3]}") == MapSet.new([%Symbol{name: "a"}, Vector.from_list([1, 2, 3])])
  end

  test "delimiters need no surrounding whitespace" do
    assert d("[1(2)3]") == Vector.from_list([1, [2], 3])
    assert d("{:a[1]:b{}}") == %{a: Vector.from_list([1]), b: %{}}
  end

  test "duplicate map keys: last wins; duplicate set elements collapse" do
    assert d("{:a 1 :a 2}") == %{a: 2}
    assert d(~S"#{1 1 2}") == MapSet.new([1, 2])
  end

  test "vectors: :list option" do
    assert d("[1 [2]]", vectors: :list) == [1, [2]]
  end

  test "discard" do
    assert d("[a b #_foo 42]") == Vector.from_list([%Symbol{name: "a"}, %Symbol{name: "b"}, 42])
    assert d("[1 #_ 2 3]") == Vector.from_list([1, 3])
    assert d("[1 #_#_ 2 3 4]") == Vector.from_list([1, 4])
    assert d("#_ {:a 1} :kept") == :kept
    assert d("#_ ; comment\n 1 2") == 2
    assert {:error, %Error.MissingDiscardExpression{line: 1, col: 4}} = EDN.decode("[1 #_]")
    assert {:error, %Error.MissingDiscardExpression{}} = EDN.decode("1 #_")
  end

  test "unbalanced and mismatched delimiters" do
    assert {:error, %Error.UnbalancedDelimiter{line: 1, col: 1}} = EDN.decode("(1 2")
    assert {:error, %Error.UnbalancedDelimiter{line: 1, col: 4}} = EDN.decode("[1 )")
    assert {:error, %Error.UnbalancedDelimiter{}} = EDN.decode("{:a 1")
    assert {:error, %Error.UnbalancedDelimiter{}} = EDN.decode(~S"#{1")
  end

  test "odd number of forms in a map" do
    assert {:error, %Error.OddExpressionCount{line: 1, col: 1}} = EDN.decode("{:a}")
  end

  test "#inst and #uuid default handlers" do
    assert d(~s(#inst "1985-04-12T23:20:50.52Z")) == ~U[1985-04-12 23:20:50.52Z]
    id = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
    assert d(~s(#uuid "#{id}")) == %UUID{value: id}
    assert {:error, %Error.InvalidTagValue{line: 1, col: 1}} = EDN.decode(~s(#inst "nope"))
    assert {:error, %Error.InvalidTagValue{}} = EDN.decode("#uuid 5")
  end

  test "unknown tags become %EDN.Tag{}; nested tags work" do
    assert d(~s(#myapp/Person {:first "Fred"})) ==
             %Tag{name: "myapp/Person", value: %{first: "Fred"}}

    assert d("#a/b #c/d 1") == %Tag{name: "a/b", value: %Tag{name: "c/d", value: 1}}
    assert d("#a/b ; note\n 1") == %Tag{name: "a/b", value: 1}
  end

  test "custom handlers override defaults and receive the decoded element" do
    handlers = %{"myapp/pt" => fn [x, y] -> {x, y} end, "inst" => fn s -> {:raw, s} end}
    assert d("#myapp/pt (1 2)", handlers: handlers) == {1, 2}
    assert d(~s(#inst "x"), handlers: handlers) == {:raw, "x"}
  end

  test "handlers are not called inside a discarded element" do
    boom = %{"x/y" => fn _ -> raise "must not run" end}
    assert d("[#_ #x/y 1 2]", handlers: boom) == Vector.from_list([2])
  end

  test "tag without an element" do
    assert {:error, %Error.IncompleteTag{line: 1, col: 1}} = EDN.decode("#a/b")
    assert {:error, %Error.IncompleteTag{}} = EDN.decode("[#a/b]")
  end

  test "reserved dispatch is an error" do
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("#1")
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("#")
  end

  test "keywords: :safe only accepts existing atoms" do
    assert d(":ok", keywords: :safe) == :ok

    assert {:error, %Error.UnexpectedInput{message: m}} =
             EDN.decode(":definitely_not_an_atom_yet_xyz", keywords: :safe)

    assert m =~ "not an existing atom"
  end

  test "nesting is capped" do
    deep = String.duplicate("[", 600) <> String.duplicate("]", 600)
    assert {:error, %Error.UnexpectedInput{message: m}} = EDN.decode(deep)
    assert m =~ "deeper than 512"
    ok = String.duplicate("[", 512) <> String.duplicate("]", 512)
    assert {:ok, _} = EDN.decode(ok)
    assert {:ok, _} = EDN.decode(deep, max_depth: 1000)
  end

  test "large inputs decode without blowing the stack" do
    big = "[" <> Enum.map_join(1..200_000, " ", &Integer.to_string/1) <> "]"
    assert {:ok, %Vector{}} = EDN.decode(big)
  end

  test "trailing closer after a complete form" do
    assert {:error, %Error.UnbalancedDelimiter{line: 1, col: 7}} = EDN.decode("{:a 1}}")
    assert {:error, %Error.UnbalancedDelimiter{}} = EDN.decode("[1 2]]")
  end

  test "tag chains and discard chains count toward the nesting cap" do
    assert {:ok, _} = EDN.decode(String.duplicate("#a/b ", 512) <> "1")

    assert {:error, %Error.UnexpectedInput{message: m}} =
             EDN.decode(String.duplicate("#a/b ", 600) <> "1")

    assert m =~ "deeper than 512"

    assert {:error, %Error.UnexpectedInput{}} =
             EDN.decode(String.duplicate("#_ ", 600) <> "1 2")

    assert EDN.decode!("#_ #_ 1 2 3") == 3
  end
end
