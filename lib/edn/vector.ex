defmodule EDN.Vector do
  @moduledoc """
  An EDN vector: indexed, with O(log n) access, backed by OTP `:array`.

  Built only through `from_list/1`, so equal contents compare `==`.

      iex> v = EDN.Vector.from_list([1, 2, 3])
      iex> EDN.Vector.get(v, 1)
      2
      iex> Enum.sum(v)
      6
  """
  defstruct array: :array.new()

  @opaque t :: %__MODULE__{array: :array.array()}

  @doc "Builds a vector from `list`."
  @spec from_list([EDN.value()]) :: t
  def from_list(list) when is_list(list), do: %__MODULE__{array: :array.from_list(list)}

  @doc "Elements in order."
  @spec to_list(t) :: [EDN.value()]
  def to_list(%__MODULE__{array: array}), do: :array.to_list(array)

  @doc "Number of elements."
  @spec size(t) :: non_neg_integer
  def size(%__MODULE__{array: array}), do: :array.size(array)

  @doc "Element at zero-based `index`, or `default` when out of range."
  @spec get(t, integer, default) :: EDN.value() | default when default: term
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
