defmodule EDN.Vector do
  @moduledoc """
  An EDN vector: indexed, with O(log n) access, backed by OTP `:array`.

  Built only through `from_list/1`, so equal contents compare `==`.
  """
  defstruct array: :array.new()

  @opaque t :: %__MODULE__{}

  @spec from_list(list) :: t
  def from_list(list) when is_list(list), do: %__MODULE__{array: :array.from_list(list)}

  @spec to_list(t) :: list
  def to_list(%__MODULE__{array: array}), do: :array.to_list(array)

  @spec size(t) :: non_neg_integer
  def size(%__MODULE__{array: array}), do: :array.size(array)

  @doc "Element at zero-based `index`, or `default` when out of range."
  @spec get(t, integer, term) :: term
  def get(%__MODULE__{array: array}, index, default \\ nil) when is_integer(index) do
    if index >= 0 and index < :array.size(array), do: :array.get(index, array), else: default
  end

  defimpl Enumerable do
    def count(v), do: {:ok, EDN.Vector.size(v)}
    def member?(_v, _x), do: {:error, __MODULE__}
    def slice(_v), do: {:error, __MODULE__}
    def reduce(v, acc, fun), do: Enumerable.List.reduce(EDN.Vector.to_list(v), acc, fun)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(v, opts),
      do: concat(["#EDN.Vector<", to_doc(EDN.Vector.to_list(v), opts), ">"])
  end
end
