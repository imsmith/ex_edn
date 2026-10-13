defmodule EDN.Symbol do
  @moduledoc """
  An EDN symbol, e.g. `my.ns/foo`.

      iex> EDN.decode!("my.ns/foo")
      %EDN.Symbol{name: "my.ns/foo"}
  """
  @enforce_keys [:name]
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}

  @spec new(String.t()) :: t
  def new(name) when is_binary(name), do: %__MODULE__{name: name}
end

defmodule EDN.Character do
  @moduledoc """
  An EDN character, e.g. `\\a` or `\\newline`. `:char` is a one-character binary.

      iex> EDN.decode!("\\\\newline")
      %EDN.Character{char: "\\n"}
  """
  @enforce_keys [:char]
  defstruct [:char]

  @type t :: %__MODULE__{char: String.t()}

  @spec new(String.t()) :: t
  def new(char) when is_binary(char), do: %__MODULE__{char: char}
end

defmodule EDN.UUID do
  @moduledoc """
  An EDN `#uuid` value. `:value` is the canonical string form.

      iex> EDN.decode!(~s(#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"))
      %EDN.UUID{value: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"}
  """
  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @spec new(String.t()) :: t
  def new(value) when is_binary(value), do: %__MODULE__{value: value}
end

defmodule EDN.Tag do
  @moduledoc """
  A tagged element with no registered handler, e.g. `#myapp/Person {...}`.
  Also holds the default `#inst` and `#uuid` handlers.

      iex> EDN.decode!("#myapp/Person {:name \\"Ada\\"}")
      %EDN.Tag{name: "myapp/Person", value: %{name: "Ada"}}
  """
  alias EDN.Error.InvalidTagValue

  @enforce_keys [:name, :value]
  defstruct [:name, :value]

  @type t :: %__MODULE__{name: String.t(), value: EDN.value()}

  @spec new(String.t(), EDN.value()) :: t
  def new(name, value) when is_binary(name), do: %__MODULE__{name: name, value: value}

  @doc """
  Default `#inst` handler: RFC 3339 string to a UTC `DateTime`.

      iex> EDN.Tag.inst("1985-04-12T23:20:50+02:00")
      ~U[1985-04-12 21:20:50Z]
  """
  @spec inst(EDN.value()) :: DateTime.t()
  def inst(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> invalid("#inst", value)
    end
  end

  def inst(value), do: invalid("#inst", value)

  @doc """
  Default `#uuid` handler: canonical UUID string to `%EDN.UUID{}`.

      iex> EDN.Tag.uuid("f81d4fae-7dec-11d0-a765-00a0c91e6bf6")
      %EDN.UUID{value: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"}
  """
  @spec uuid(EDN.value()) :: EDN.UUID.t()
  def uuid(value) when is_binary(value) do
    if Regex.match?(
         ~r/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/,
         value
       ),
       do: %EDN.UUID{value: value},
       else: invalid("#uuid", value)
  end

  def uuid(value), do: invalid("#uuid", value)

  @spec invalid(String.t(), term) :: no_return
  defp invalid(tag, value),
    do: raise(InvalidTagValue, message: "invalid #{tag} value: #{inspect(value)}")
end
