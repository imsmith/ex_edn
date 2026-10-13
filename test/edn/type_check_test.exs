defmodule EDN.TypeCheckTest do
  use ExUnit.Case, async: true

  # Elixir 1.20 infers argument types from our guards and patterns and checks
  # callers against them. This pins that EDN's inferred types reach callers.
  test "the compiler flags a call that violates an inferred EDN type" do
    source = ~S"""
    defmodule EDN.TypeCheckTest.BadCaller do
      def run, do: EDN.Vector.get(EDN.Vector.from_list([1]), "not an index")
    end
    """

    {_result, diagnostics} =
      Code.with_diagnostics(fn ->
        Code.compile_string(source)
      end)

    :code.purge(EDN.TypeCheckTest.BadCaller)
    :code.delete(EDN.TypeCheckTest.BadCaller)

    assert [%{severity: :warning, message: message}] = diagnostics
    assert message =~ "incompatible types given to EDN.Vector.get/2"
  end
end
