defmodule PiEx.DeepAgent.Tools.TruncateTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Truncate

  describe "truncate_head/2" do
    test "returns content unchanged when within limits" do
      content = Enum.map_join(1..10, "\n", &"line #{&1}")
      {result, meta} = Truncate.truncate_head(content)
      assert result == content
      assert meta.truncated == false
      assert meta.lines_removed == 0
    end

    test "truncates by line count" do
      content = Enum.map_join(1..10, "\n", &"line #{&1}")
      {result, meta} = Truncate.truncate_head(content, max_lines: 3)
      assert result == "line 1\nline 2\nline 3"
      assert meta.truncated == true
      assert meta.lines_removed == 7
    end

    test "truncates by byte limit" do
      # Each line is "XXXXXXXXXX\n" = 11 bytes; set max_bytes to 25 to allow only 2 lines
      content = Enum.map_join(1..5, "\n", fn _ -> "XXXXXXXXXX" end)
      {result, meta} = Truncate.truncate_head(content, max_bytes: 25)
      assert meta.truncated == true
      assert meta.lines_removed > 0
      assert byte_size(result) <= 25
    end

    test "handles empty content" do
      {result, meta} = Truncate.truncate_head("")
      assert result == ""
      assert meta.truncated == false
    end

    test "handles content exactly at line limit" do
      content = Enum.map_join(1..5, "\n", &"line #{&1}")
      {result, meta} = Truncate.truncate_head(content, max_lines: 5)
      assert result == content
      assert meta.truncated == false
      assert meta.lines_removed == 0
    end
  end

  describe "truncate_tail/2" do
    test "returns content unchanged when within limits" do
      content = Enum.map_join(1..5, "\n", &"line #{&1}")
      {result, meta} = Truncate.truncate_tail(content)
      assert result == content
      assert meta.truncated == false
    end

    test "keeps the end of the content" do
      content = Enum.map_join(1..10, "\n", &"line #{&1}")
      {result, meta} = Truncate.truncate_tail(content, max_lines: 3)
      assert result == "line 8\nline 9\nline 10"
      assert meta.truncated == true
      assert meta.lines_removed == 7
    end

    test "handles empty content" do
      {result, meta} = Truncate.truncate_tail("")
      assert meta.truncated == false
      assert result == ""
    end
  end

  describe "truncate_line/2" do
    test "returns line unchanged when within limit" do
      assert Truncate.truncate_line("hello", 10) == "hello"
    end

    test "truncates long line and appends ellipsis" do
      long = String.duplicate("x", 600)
      result = Truncate.truncate_line(long, 500)
      assert String.ends_with?(result, "...")
      assert String.length(result) == 503
    end

    test "handles exactly at limit" do
      line = String.duplicate("x", 500)
      assert Truncate.truncate_line(line, 500) == line
    end
  end
end
