defmodule EDN.Decoder do
  @moduledoc false
  # One recursive-descent pass over the binary. `rest` is always a suffix of
  # `ctx.input`, so error positions are computed from byte offsets on failure
  # only; there is no per-character line/column bookkeeping.

  alias EDN.{Character, Symbol}
  alias EDN.Error

  @ws [?\s, ?\t, ?\n, ?\r, ?,]
  @closers [?), ?], ?}]
  @delims @ws ++ [?{, ?}, ?(, ?), ?[, ?], ?", ?;]

  @doc "Decodes every top-level form in `input` into a list."
  def forms(input, opts) do
    unless String.valid?(input),
      do: raise(Error.UnexpectedInput, message: "input is not valid UTF-8")

    # Files saved by some editors start with a UTF-8 byte order mark.
    input = String.replace_prefix(input, "\uFEFF", "")

    ctx = %{
      input: input,
      handlers: Keyword.fetch!(opts, :handlers),
      keywords: Keyword.fetch!(opts, :keywords),
      vectors: Keyword.fetch!(opts, :vectors),
      max_depth: Keyword.fetch!(opts, :max_depth),
      discard: false
    }

    forms(input, ctx, [])
  end

  defp forms(rest, ctx, acc) do
    case skip(rest, ctx, 0) do
      "" ->
        Enum.reverse(acc)

      rest ->
        {value, rest} = value(rest, ctx, 0)
        forms(rest, ctx, [value | acc])
    end
  end

  # -- whitespace and comments ------------------------------------------------

  defp skip(<<c, rest::binary>>, ctx, depth) when c in @ws, do: skip(rest, ctx, depth)

  defp skip(<<?;, rest::binary>>, ctx, depth) do
    case :binary.split(rest, "\n") do
      [_comment_to_eof] -> ""
      [_comment, rest] -> skip(rest, ctx, depth)
    end
  end

  defp skip(rest, _ctx, _depth), do: rest

  # -- values -------------------------------------------------------------------

  defp value(<<c, _::binary>> = at, ctx, _depth) when c in @closers,
    do: fail(Error.UnbalancedDelimiter, ctx, at, "unexpected #{<<c>>}")

  defp value(<<?", rest::binary>> = at, ctx, _depth), do: string(rest, at, ctx, [])

  defp value(<<?\\, rest::binary>> = at, ctx, _depth) do
    case rest do
      <<c::utf8, tail::binary>> when c not in @ws ->
        {more, tail} = token(tail)
        {%Character{char: char_name(<<c::utf8>> <> more, ctx, at)}, tail}

      _ ->
        fail(Error.UnexpectedInput, ctx, at, "backslash must be followed by a character")
    end
  end

  defp value(rest, ctx, _depth) do
    case token(rest) do
      {"", _} -> fail(Error.UnexpectedInput, ctx, rest, "unexpected input")
      {token, tail} -> {atom(token, ctx, rest), tail}
    end
  end

  # -- strings and characters -----------------------------------------------------

  defp string(rest, at, ctx, acc) do
    case :binary.match(rest, [~s("), "\\"]) do
      :nomatch ->
        fail(Error.UnfinishedToken, ctx, at, "unterminated string")

      {i, 1} ->
        <<chunk::binary-size(i), c, tail::binary>> = rest
        acc = [acc, chunk]

        case {c, tail} do
          {?", _} ->
            {IO.iodata_to_binary(acc), tail}

          {?\\, <<?u, hex::binary-size(4), tail::binary>>} ->
            case unicode(hex) do
              {:ok, char} -> string(tail, at, ctx, [acc, char])
              :error -> fail(Error.UnexpectedInput, ctx, tail, "invalid \\u escape")
            end

          {?\\, <<?t, tail::binary>>} ->
            string(tail, at, ctx, [acc, "\t"])

          {?\\, <<?r, tail::binary>>} ->
            string(tail, at, ctx, [acc, "\r"])

          {?\\, <<?n, tail::binary>>} ->
            string(tail, at, ctx, [acc, "\n"])

          {?\\, <<?\\, tail::binary>>} ->
            string(tail, at, ctx, [acc, "\\"])

          {?\\, <<?", tail::binary>>} ->
            string(tail, at, ctx, [acc, ~s(")])

          {?\\, ""} ->
            fail(Error.UnfinishedToken, ctx, at, "unterminated string")

          {?\\, tail} ->
            fail(Error.UnexpectedInput, ctx, tail, "invalid escape in string")
        end
    end
  end

  defp char_name("newline", _, _), do: "\n"
  defp char_name("return", _, _), do: "\r"
  defp char_name("space", _, _), do: " "
  defp char_name("tab", _, _), do: "\t"

  defp char_name(<<?u, hex::binary-size(4)>> = token, ctx, at) do
    case unicode(hex) do
      {:ok, char} -> char
      :error -> char_name_fallback(token, ctx, at)
    end
  end

  defp char_name(token, ctx, at), do: char_name_fallback(token, ctx, at)

  defp char_name_fallback(token, ctx, at) do
    if String.length(token) == 1,
      do: token,
      else: fail(Error.UnexpectedInput, ctx, at, "unknown character \\#{token}")
  end

  # `\uNNNN` as in Java. Surrogate halves are not scalar values: rejected.
  defp unicode(hex) do
    with true <- Regex.match?(~r/\A[0-9a-fA-F]{4}\z/, hex),
         {cp, ""} <- Integer.parse(hex, 16),
         true <- cp not in 0xD800..0xDFFF do
      {:ok, <<cp::utf8>>}
    else
      _ -> :error
    end
  end

  # -- atoms: nil, booleans, numbers, keywords, symbols ---------------------------

  defp atom("nil", _, _), do: nil
  defp atom("true", _, _), do: true
  defp atom("false", _, _), do: false
  defp atom(":" <> name, ctx, at), do: keyword(name, ctx, at)
  defp atom(<<c, _::binary>> = token, ctx, at) when c in ?0..?9, do: number(token, ctx, at)

  defp atom(<<s, d, _::binary>> = token, ctx, at) when s in [?+, ?-] and d in ?0..?9,
    do: number(token, ctx, at)

  defp atom(token, ctx, at) do
    if symbol_name?(token),
      do: %Symbol{name: token},
      else: fail(Error.UnexpectedInput, ctx, at, "invalid symbol #{inspect(token)}")
  end

  defp keyword(name, ctx, at) do
    unless name != "/" and symbol_name?(name),
      do: fail(Error.UnexpectedInput, ctx, at, "invalid keyword :#{name}")

    case ctx.keywords do
      :atom ->
        String.to_atom(name)

      :safe ->
        try do
          String.to_existing_atom(name)
        rescue
          ArgumentError ->
            fail(Error.UnexpectedInput, ctx, at, "keyword :#{name} is not an existing atom")
        end
    end
  end

  defp number(token, ctx, at) do
    cond do
      Regex.match?(~r/\A[+-]?(?:0|[1-9][0-9]*)N?\z/, token) ->
        token |> String.trim_trailing("N") |> String.to_integer()

      Regex.match?(~r/\A[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?M?\z/, token) ->
        case token |> String.trim_trailing("M") |> Float.parse() do
          {float, ""} -> float
          _ -> fail(Error.UnexpectedInput, ctx, at, "number out of range: #{token}")
        end

      true ->
        fail(Error.UnexpectedInput, ctx, at, "invalid number #{inspect(token)}")
    end
  end

  # Symbol grammar from the spec: first char non-numeric; a leading - + . must
  # not be followed by a digit; `/` once, with non-empty prefix and name, or
  # alone.
  defp symbol_name?("/"), do: true

  defp symbol_name?(token) do
    case String.split(token, "/") do
      [name] -> symbol_part?(name)
      [prefix, name] -> symbol_part?(prefix) and symbol_part?(name)
      _ -> false
    end
  end

  defp symbol_part?(part),
    do:
      Regex.match?(
        ~r/\A(?:[\p{L}*!_?$%&=<>]|[-+.](?![0-9]))[\p{L}\p{N}.*+!\-_?$%&=<>:#]*\z/u,
        part
      )

  # -- helpers ------------------------------------------------------------------------

  # Splits off bytes up to the next whitespace or delimiter.
  defp token(bin), do: token(bin, 0)

  defp token(bin, n) do
    case bin do
      <<_::binary-size(n), c, _::binary>> when c not in @delims -> token(bin, n + 1)
      _ -> {binary_part(bin, 0, n), binary_part(bin, n, byte_size(bin) - n)}
    end
  end

  defp fail(module, ctx, rest, message) do
    {line, col} = position(ctx.input, rest)

    raise module,
      message: "#{message} at line #{line}, column #{col}",
      line: line,
      col: col
  end

  defp position(input, rest) do
    consumed = binary_part(input, 0, byte_size(input) - byte_size(rest))
    lines = String.split(consumed, "\n")
    {length(lines), String.length(List.last(lines)) + 1}
  end
end
