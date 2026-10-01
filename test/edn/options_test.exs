defmodule EDN.OptionsTest do
  use ExUnit.Case, async: true

  test "invalid option values raise ArgumentError, naming the option" do
    for {key, value} <- [
          keywords: :bogus,
          vectors: :tuple,
          max_depth: 0,
          max_depth: "deep",
          handlers: [],
          handlers: %{"a/b" => :not_a_function},
          handlers: %{"a/b" => fn _, _ -> :wrong_arity end}
        ] do
      assert_raise ArgumentError, ~r/#{key}/, fn -> EDN.decode("1", [{key, value}]) end
      assert_raise ArgumentError, ~r/#{key}/, fn -> EDN.decode!("1", [{key, value}]) end
    end
  end

  test "valid options are unchanged" do
    assert EDN.decode!("[1]", vectors: :list, keywords: :safe, max_depth: 1, handlers: %{}) == [1]
  end
end
