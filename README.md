# ex_edn

EDN (extensible data notation) reader and writer for Elixir. No dependencies.

```elixir
iex> EDN.decode("{:a 1, :b [1 2 3]}")
{:ok, %{a: 1, b: #EDN.Vector<[1, 2, 3]>}}

iex> EDN.encode(%{a: 1})
{:ok, "{:a 1}"}
```

## Type mapping

| EDN | Elixir |
| --- | --- |
| `nil`, `true`, `false` | `nil`, `true`, `false` |
| string | binary |
| integer, float (`N`, `M` suffixes accepted) | integer, float |
| keyword | atom |
| list | list |
| vector | `%EDN.Vector{}` |
| map | map |
| set | `MapSet` |
| symbol | `%EDN.Symbol{}` |
| character | `%EDN.Character{}` |
| `#inst` | `%DateTime{}` (UTC) |
| `#uuid` | `%EDN.UUID{}` |
| unknown tag | `%EDN.Tag{}` |

Decoding one top-level form returns its value; several forms return a list.

## Options

- `handlers:` a map of tag name to function, merged over the `inst` and `uuid` defaults.
- `keywords: :safe` uses `String.to_existing_atom/1`. The default, `String.to_atom/1`, lets untrusted input grow the atom table; use `:safe` for anything you do not control.
- `vectors: :list` decodes vectors to plain lists.
- `max_depth:` nesting limit, default 512.

## Errors

`decode/2` and `encode/1` return `{:error, exception}`. Decode errors are `EDN.Error.*` structs carrying `:line` and `:col`.

## Notes

- Encoding writes elements separated by `", "`. Map entry order is unspecified, as in EDN itself.
- Charlists encode as lists of integers. Tuples, pids and other non-EDN terms return an error.
- Binaries that are not valid UTF-8 are rejected on encode.

## Migrating from Eden

Rename `Eden` to `EDN`, `Array.from_list/to_list` to `EDN.Vector.from_list/to_list`, and `Eden.Symbol` and friends to `EDN.Symbol` and friends. Errors are now `{:error, %EDN.Error.X{}}` instead of `{:error, Eden.Exception.X}`.

## License

AGPL-3.0-only.
