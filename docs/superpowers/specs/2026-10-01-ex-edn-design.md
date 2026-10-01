# ex_edn design

Date: 2026-10-01
Status: awaiting review

## Purpose

A maintained, dependency-free EDN reader and writer for Elixir that replaces
[Eden](https://github.com/jfacorro/Eden) (`eden ~> 2.1`, forked at
`~/github/Eden`). Eden depends on `elixir_array` and `timex`, which are no
longer updated. The spec being implemented is `edn/edn.md` (symlink to
`~/github/standards/data/edn/edn.md`).

## Success criteria

- `wagger`, `llmagent` and `yesman_instance` migrate by mechanical rename
  (`Eden` to `EDN`, `Array` to `EDN.Vector`), with no logic changes beyond
  error matching.
- Zero runtime dependencies.
- Every example in `edn.md` decodes and encodes as specified.

## Non-goals

- No `Eden` module or shim. The `Eden` name is not used.
- No streaming reader, `#:ns{}` map namespacing, or bigdecimal for `M`
  (floats map to Erlang floats, as in Eden).
- No tuple encoding.

## Package

- Hex package `ex_edn`, OTP app `:ex_edn`, namespace `EDN`.
- Hex name availability is unchecked; verify before publishing.
- License AGPLv3. SPDX SBOM at first release.
- Written fresh. Only the public API shape is matched to Eden, so Eden's
  Apache-2.0 code is not carried over.

## API

| Function | Behavior |
| --- | --- |
| `EDN.decode(input, opts \\ [])` | `{:ok, value} \| {:error, %EDN.Error.*{}}` |
| `EDN.decode!(input, opts \\ [])` | value, or raises |
| `EDN.encode(term)` | `{:ok, string} \| {:error, exception}` |
| `EDN.encode!(term)` | string, or raises |

One expression decodes to its value; several decode to a list (Eden's
behavior, kept so migration stays mechanical). Empty input raises
`EDN.Error.EmptyInput`.

### Options (decode)

- `handlers: %{"ns/tag" => fun}` registers tag handlers. Defaults `inst` and
  `uuid` are always present and can be overridden.
- `keywords: :safe` uses `String.to_existing_atom/1`. Default is
  `String.to_atom/1`, as in Eden. The atom-table risk on untrusted input is
  documented.
- `vectors: :list` decodes vectors to plain lists. Default is `%EDN.Vector{}`.

## Type mapping

| EDN | Elixir |
| --- | --- |
| `nil`, `true`, `false` | `nil`, `true`, `false` |
| string | binary |
| integer (`N` suffix ignored) | integer |
| float (`M` suffix ignored) | float |
| keyword | atom |
| list | list |
| vector | `%EDN.Vector{}` |
| map | map |
| set | `MapSet` |
| symbol | `%EDN.Symbol{name: binary}` |
| character | `%EDN.Character{char: binary}` |
| `#inst` | `%DateTime{}` (UTC) |
| `#uuid` | `%EDN.UUID{value: binary}` |
| unknown tag | `%EDN.Tag{name: binary, value: term}` |

Comments and `#_` discards are consumed by the parser. Handlers are not
called inside a discarded element, per spec.

## Components

- `EDN` is the public API and option handling.
- `EDN.Decoder` is one recursive-descent parser over the binary. It tracks line
  and column for errors. It makes no separate lexer pass.
- `EDN.Encode` is a protocol with a fallback to `Any`. Structs fall back to
  maps via `Map.from_struct/1`. Encoders exist for atom, binary, integer,
  float, list, map, `MapSet`, `DateTime`, and the types in this package.
  Strings are escaped (`\"`, `\\`, `\n`, `\r`, `\t`); Eden did not escape.
- `EDN.Vector` is a struct wrapping OTP `:array`. It has `from_list/1`,
  `to_list/1`, `get/2`, `size/1`, and `Enumerable` and `Inspect`
  implementations. Eden's `Array` name is deliberately not used, so there is
  no clash with `elixir_array`.
- `EDN.Symbol`, `EDN.Character`, `EDN.UUID` and `EDN.Tag` are small structs
  with `new/1` or `new/2`.
- `EDN.Error.*` are exceptions with `:message`, `:line` and `:col`:
  `UnexpectedInput`, `UnfinishedToken`, `UnbalancedDelimiter`,
  `OddExpressionCount`, `IncompleteTag`, `MissingDiscardExpression`,
  `EmptyInput`, `InvalidTagValue`.

## Deliberate departure from Eden

Errors are `{:error, %EDN.Error.X{}}` with position data. Eden returned the bare
module (`{:error, Eden.Exception.X}`). Callers that pattern-match on the module
need a one-line change. Everything else in the mapping is unchanged apart from
the renames.

## Error handling and safety

- Parsing is bounded by input size. Nesting depth is capped (default 512,
  option `max_depth:`) so hostile input cannot exhaust the stack.
- Invalid UTF-8 returns `UnexpectedInput`.
- Duplicate map keys and set elements: last write wins for maps, deduplicated
  for sets. The spec calls duplicates an error ("should appear at most
  once"), so this stays as lenient as Eden. Revisit if strictness is wanted.

## Testing

ExUnit, written fresh:

- Each example in `edn.md`, as decode and encode cases.
- Round trips for every type in the mapping table.
- Malformed input per error type, asserting line and column.
- Tag handlers, discard, comments, comma whitespace, and the `-`/`+`/`.`
  symbol edge cases.
- Nesting-depth cap and invalid UTF-8.

## Migration notes for existing projects

- `mix.exs`: replace `{:eden, "~> 2.1"}` with `{:ex_edn, path_or_version}`.
- Rename `Eden.` to `EDN.`, and `Array.from_list/to_list` to
  `EDN.Vector.from_list/to_list`.
- Update any `{:error, Eden.Exception.X}` match.
- Known callers: `wagger/lib/wagger/ecto/edn_list.ex`,
  `wagger/lib/wagger/ecto/edn_map_list.ex`,
  `llmagent/lib/llmagent/discovery/wire.ex`, and the `yesman_instance` dep.
