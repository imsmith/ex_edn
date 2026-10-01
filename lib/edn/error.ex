defmodule EDN.Error do
  @moduledoc """
  Exceptions raised by `EDN.decode!/2` and `EDN.encode!/1`.

  Every exception carries `:message`, and `:line` and `:col` (1-based) when
  the problem has a position in the input.
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
      defexception [:message, :line, :col]
    end
  end

  @doc false
  def all, do: unquote(for name <- @names, do: Module.concat(__MODULE__, name))
end
