defmodule EDN.Error do
  @moduledoc """
  Exceptions raised by `EDN.decode!/2` and `EDN.encode!/1`.

  Every exception carries `:message`, and `:line` and `:col` (1-based) when
  the problem has a position in the input. `t/0` is the union of them all.

      iex> {:error, %EDN.Error.UnbalancedDelimiter{line: 1, col: 1}} = EDN.decode("[1 2")
      iex> EDN.decode("")
      {:error, %EDN.Error.EmptyInput{message: "no EDN forms in input", line: nil, col: nil}}
  """

  @names [
    UnexpectedInput,
    UnfinishedToken,
    UnbalancedDelimiter,
    OddExpressionCount,
    IncompleteTag,
    MissingDiscardExpression,
    EmptyInput,
    InvalidTagValue
  ]

  for name <- @names do
    defmodule Module.concat(__MODULE__, name) do
      @moduledoc "See `EDN.Error`."
      defexception [:message, :line, :col]

      @type t :: %__MODULE__{
              message: String.t(),
              line: pos_integer | nil,
              col: pos_integer | nil
            }
    end
  end

  @typedoc "Any exception in this module."
  @type t ::
          unquote(
            @names
            |> Enum.map(&quote(do: unquote(Module.concat(__MODULE__, &1)).t()))
            |> Enum.reduce(&quote(do: unquote(&2) | unquote(&1)))
          )

  @doc false
  @spec all :: [module]
  def all, do: unquote(for name <- @names, do: Module.concat(__MODULE__, name))
end
