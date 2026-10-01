defmodule EDN.TypesTest do
  use ExUnit.Case, async: true
  alias EDN.{Vector, Tag, UUID, Error}

  test "vector round trip, size, get, enumerable, inspect" do
    v = Vector.from_list([1, :a, "x"])
    assert Vector.to_list(v) == [1, :a, "x"]
    assert Vector.size(v) == 3
    assert Vector.get(v, 1) == :a
    assert Vector.get(v, 3) == nil
    assert Vector.get(v, -1, :none) == :none
    assert Enum.map(v, & &1) == [1, :a, "x"]
    assert Enum.count(v) == 3
    assert Vector.from_list([1, 2]) == Vector.from_list([1, 2])
    assert inspect(v) == ~s(#EDN.Vector<[1, :a, "x"]>)
  end

  test "default #inst handler yields a UTC DateTime" do
    assert Tag.inst("1985-04-12T23:20:50.52Z") ==
             ~U[1985-04-12 23:20:50.52Z]

    assert Tag.inst("1985-04-12T23:20:50+02:00") == ~U[1985-04-12 21:20:50Z]
    assert_raise Error.InvalidTagValue, fn -> Tag.inst("yesterday") end
    assert_raise Error.InvalidTagValue, fn -> Tag.inst(5) end
  end

  test "default #uuid handler" do
    id = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
    assert Tag.uuid(id) == %UUID{value: id}
    assert_raise Error.InvalidTagValue, fn -> Tag.uuid("nope") end
  end
end
