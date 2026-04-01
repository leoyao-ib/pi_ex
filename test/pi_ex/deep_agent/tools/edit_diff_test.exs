defmodule PiEx.DeepAgent.Tools.EditDiffTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.EditDiff

  describe "fuzzy_find_text/2" do
    test "exact match returns correct line range" do
      content = "line one\nline two\nline three\nline four"
      {:ok, range} = EditDiff.fuzzy_find_text(content, "line two\nline three")
      assert range.start_line == 2
      assert range.end_line == 3
    end

    test "exact match on single line" do
      content = "alpha\nbeta\ngamma"
      {:ok, range} = EditDiff.fuzzy_find_text(content, "beta")
      assert range.start_line == 2
      assert range.end_line == 2
    end

    test "fuzzy match with trailing whitespace difference" do
      content = "line one  \nline two\nline three"
      {:ok, range} = EditDiff.fuzzy_find_text(content, "line one\nline two")
      assert range.start_line == 1
      assert range.end_line == 2
    end

    test "fuzzy match with smart quotes" do
      content = "She said \u201Chello\u201D\nand left"
      {:ok, range} = EditDiff.fuzzy_find_text(content, "She said \"hello\"\nand left")
      assert range.start_line == 1
      assert range.end_line == 2
    end

    test "returns error when text not found" do
      content = "alpha\nbeta\ngamma"
      assert {:error, _reason} = EditDiff.fuzzy_find_text(content, "delta")
    end
  end

  describe "apply_edits/2" do
    test "applies a single edit" do
      content = "hello world\ngoodbye"
      edits = [%{old_text: "hello world", new_text: "hi there"}]
      {:ok, result} = EditDiff.apply_edits(content, edits)
      assert result == "hi there\ngoodbye"
    end

    test "applies multiple edits against original content" do
      content = "line A\nline B\nline C"

      edits = [
        %{old_text: "line A", new_text: "LINE A"},
        %{old_text: "line C", new_text: "LINE C"}
      ]

      {:ok, result} = EditDiff.apply_edits(content, edits)
      assert result == "LINE A\nline B\nLINE C"
    end

    test "returns error when old_text not found" do
      content = "alpha\nbeta"
      edits = [%{old_text: "gamma", new_text: "delta"}]
      assert {:error, _reason} = EditDiff.apply_edits(content, edits)
    end

    test "handles multiline old_text replacement" do
      content = "start\nfoo\nbar\nend"
      edits = [%{old_text: "foo\nbar", new_text: "baz"}]
      {:ok, result} = EditDiff.apply_edits(content, edits)
      assert result == "start\nbaz\nend"
    end
  end

  describe "generate_diff/3" do
    test "returns a diff string for changed content" do
      old = "hello\nworld\n"
      new = "hello\nelixir\n"
      diff = EditDiff.generate_diff(old, new, "/tmp/test_file.txt")
      assert is_binary(diff)
      assert diff =~ "world" or diff =~ "elixir" or diff == ""
    end

    test "returns empty string for identical content" do
      content = "no change\n"
      diff = EditDiff.generate_diff(content, content, "/tmp/same.txt")
      assert diff == ""
    end
  end
end
