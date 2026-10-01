defmodule EDN.Symbol do
  @moduledoc "An EDN symbol, e.g. `my.ns/foo`."
  defstruct [:name]
  def new(name) when is_binary(name), do: %__MODULE__{name: name}
end

defmodule EDN.Character do
  @moduledoc "An EDN character, e.g. `\\a` or `\\newline`. `:char` is a one-character binary."
  defstruct [:char]
  def new(char) when is_binary(char), do: %__MODULE__{char: char}
end

defmodule EDN.UUID do
  @moduledoc "An EDN `#uuid` value. `:value` is the canonical string form."
  defstruct [:value]
  def new(value) when is_binary(value), do: %__MODULE__{value: value}
end

defmodule EDN.Tag do
  @moduledoc """
  A tagged element with no registered handler, e.g. `#myapp/Person {...}`.
  Also holds the default `#inst` and `#uuid` handlers.
  """
  alias EDN.Error.InvalidTagValue

  defstruct [:name, :value]
  def new(name, value) when is_binary(name), do: %__MODULE__{name: name, value: value}

  @doc "Default `#inst` handler: RFC 3339 string to a UTC `DateTime`."
  def inst(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> invalid("#inst", value)
    end
  end

  def inst(value), do: invalid("#inst", value)

  @doc "Default `#uuid` handler: canonical UUID string to `%EDN.UUID{}`."
  def uuid(value) when is_binary(value) do
    if Regex.match?(
         ~r/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/,
         value
       ),
       do: %EDN.UUID{value: value},
       else: invalid("#uuid", value)
  end

  def uuid(value), do: invalid("#uuid", value)

  defp invalid(tag, value),
    do: raise(InvalidTagValue, message: "invalid #{tag} value: #{inspect(value)}")
end
