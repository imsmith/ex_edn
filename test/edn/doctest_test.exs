defmodule EDN.DoctestTest do
  use ExUnit.Case, async: true
  doctest EDN
  doctest EDN.Vector
  doctest EDN.Symbol
  doctest EDN.Character
  doctest EDN.UUID
  doctest EDN.Tag
  doctest EDN.Error
  doctest EDN.Encode
end
