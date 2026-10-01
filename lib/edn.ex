defmodule EDN do
  @moduledoc """
  EDN (extensible data notation) reader and writer. See `decode/2` and
  `encode/1`. No runtime dependencies.
  """

  alias EDN.Error

  @default_handlers %{"inst" => &EDN.Tag.inst/1, "uuid" => &EDN.Tag.uuid/1}

  @doc """
  Decodes EDN text. One top-level form returns its value; several return a
  list of values.

  ## Options

    * `:handlers` - `%{"my/tag" => fun}`; `fun` receives the decoded tagged
      element. Merged over the default `inst` and `uuid` handlers.
    * `:keywords` - `:atom` (default, `String.to_atom/1`) or `:safe`
      (`String.to_existing_atom/1`). Use `:safe` on untrusted input: atoms are
      never garbage collected.
    * `:vectors` - `:vector` (default, `%EDN.Vector{}`) or `:list`.
    * `:max_depth` - maximum nesting depth, default 512.
  """
  @spec decode(String.t(), keyword) :: {:ok, term} | {:error, Exception.t()}
  def decode(input, opts \\ []) do
    {:ok, decode!(input, opts)}
  rescue
    e -> to_error(e, __STACKTRACE__)
  end

  @doc "Like `decode/2`, but returns the value and raises `EDN.Error.*` on failure."
  @spec decode!(String.t(), keyword) :: term
  def decode!(input, opts \\ []) when is_binary(input) do
    opts = [
      handlers: Map.merge(@default_handlers, Keyword.get(opts, :handlers, %{})),
      keywords: Keyword.get(opts, :keywords, :atom),
      vectors: Keyword.get(opts, :vectors, :vector),
      max_depth: Keyword.get(opts, :max_depth, 512)
    ]

    case EDN.Decoder.forms(input, opts) do
      [] -> raise Error.EmptyInput, message: "no EDN forms in input"
      [form] -> form
      forms -> forms
    end
  end

  defp to_error(%{__struct__: module} = e, stacktrace) do
    if module in Error.all(), do: {:error, e}, else: reraise(e, stacktrace)
  end
end
