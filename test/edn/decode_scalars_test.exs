defmodule EDN.DecodeScalarsTest do
  use ExUnit.Case, async: true
  alias EDN.{Symbol, Character, Error}

  defp d(s), do: EDN.decode!(s)

  test "nil and booleans" do
    assert d("nil") == nil
    assert d("true") == true
    assert d("false") == false
  end

  test "integers" do
    assert d("0") == 0
    assert d("-0") == 0
    assert d("42") == 42
    assert d("+42") == 42
    assert d("-17") == -17
    assert d("123456789012345678901234567890N") == 123_456_789_012_345_678_901_234_567_890
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("01")
  end

  test "floats" do
    assert d("1.5") == 1.5
    assert d("-0.25") == -0.25
    assert d("1e3") == 1000.0
    assert d("1E-2") == 0.01
    assert d("2.5e+2") == 250.0
    assert d("3M") == 3.0
    assert d("1.5M") == 1.5
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("1e999")
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("1.")
  end

  test "strings and escapes" do
    assert d(~s("")) == ""
    assert d(~s("héllo")) == "héllo"
    assert d(~S("a\tb\r\nc\\d\"e")) == "a\tb\r\nc\\d\"e"
    assert d(~S("é")) == "é"
    assert d("\"two\nlines\"") == "two\nlines"
    assert {:error, %Error.UnfinishedToken{line: 1, col: 1}} = EDN.decode(~s("abc))
    assert {:error, %Error.UnfinishedToken{}} = EDN.decode(~S("abc\\))
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode(~S("\q"))
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode(~S("\ud800"))
  end

  test "characters" do
    assert d("\\a") == %Character{char: "a"}
    assert d("\\newline") == %Character{char: "\n"}
    assert d("\\return") == %Character{char: "\r"}
    assert d("\\space") == %Character{char: " "}
    assert d("\\tab") == %Character{char: "\t"}
    assert d("\\u00e9") == %Character{char: "é"}
    assert d("\\(") == %Character{char: "("}
    assert d("\\é") == %Character{char: "é"}
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("\\ ")
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode("\\foo")
  end

  test "keywords" do
    assert d(":a") == :a
    assert d(":my/fred") == :"my/fred"
    assert d(":a.b/c-d?") == :"a.b/c-d?"

    for bad <- [":", ":/", ":/a", "::a", ":a/", ":1a"] do
      assert {:error, %Error.UnexpectedInput{}} = EDN.decode(bad), bad
    end
  end

  test "symbols" do
    assert d("foo") == %Symbol{name: "foo"}
    assert d("my-ns/foo") == %Symbol{name: "my-ns/foo"}
    assert d("/") == %Symbol{name: "/"}
    assert d("-") == %Symbol{name: "-"}
    assert d("-a") == %Symbol{name: "-a"}
    assert d("-.5") == %Symbol{name: "-.5"}
    assert d(".") == %Symbol{name: "."}
    assert d("a:b#c") == %Symbol{name: "a:b#c"}
    assert d("nilly") == %Symbol{name: "nilly"}

    for bad <- ["a/", "/a", "a/b/c", "+1a", "@x"] do
      assert {:error, %Error.UnexpectedInput{}} = EDN.decode(bad), bad
    end
  end

  test "whitespace, commas and comments separate forms" do
    assert d("1,2 ,3\n4") == [1, 2, 3, 4]
    assert d("; leading\n:a ; trailing") == :a
    assert d("  \t\n :a") == :a
  end

  test "several forms give a list, one gives the value, none raises" do
    assert d("nil true false") == [nil, true, false]
    assert d(":a") == :a
    assert {:error, %Error.EmptyInput{}} = EDN.decode("")
    assert {:error, %Error.EmptyInput{}} = EDN.decode("  ; only a comment")
  end

  test "positions are 1-based line and column" do
    assert {:error, %Error.UnexpectedInput{line: 3, col: 4, message: msg}} =
             EDN.decode("1\n2\n   @x")

    assert msg =~ "line 3, column 4"
  end

  test "invalid UTF-8 is an error, not a crash" do
    assert {:error, %Error.UnexpectedInput{}} = EDN.decode(<<0xFF, 0xFE>>)
  end

  test "a stray closer at top level" do
    assert {:error, %Error.UnbalancedDelimiter{line: 1, col: 3}} = EDN.decode("1 )")
  end

  test "a leading byte order mark is ignored" do
    assert d(<<0xEF, 0xBB, 0xBF>> <> ":a") == :a
  end

  test "CRLF line endings, including after comments" do
    assert d("; comment\r\n:a\r\n1\r\n") == [:a, 1]
    assert {:error, %Error.UnexpectedInput{line: 2}} = EDN.decode("1\r\n@")
  end

  test "a keyword over the 255-character atom limit is an error, not a crash" do
    assert {:ok, _} = EDN.decode(":" <> String.duplicate("a", 255))

    assert {:error, %Error.UnexpectedInput{line: 1, col: 1}} =
             EDN.decode(":" <> String.duplicate("a", 256))
  end

  test "a float literal too long for the VM is an error, not a crash" do
    assert {:ok, _} = EDN.decode("1" <> String.duplicate("0", 308) <> ".0")

    assert {:error, %Error.UnexpectedInput{}} =
             EDN.decode("1" <> String.duplicate("0", 309) <> ".0")
  end
end
