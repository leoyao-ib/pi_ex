defmodule PiEx.DeepAgent.Tools.GrepTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Grep

  setup do
    dir = System.tmp_dir!() |> Path.join("grep_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    @tag :requires_rg
    test "finds pattern matches", %{dir: dir} do
      File.write!(Path.join(dir, "a.txt"), "hello world\nfoo bar\n")
      File.write!(Path.join(dir, "b.txt"), "goodbye world\n")
      {:ok, result} = Grep.execute(%{pattern: "world", path: "."}, dir)
      assert result =~ "world"
    end

    @tag :requires_rg
    test "case insensitive search", %{dir: dir} do
      File.write!(Path.join(dir, "c.txt"), "Hello World\n")
      {:ok, result} = Grep.execute(%{pattern: "hello", path: ".", ignore_case: true}, dir)
      assert result =~ "Hello"
    end

    @tag :requires_rg
    test "literal string search", %{dir: dir} do
      File.write!(Path.join(dir, "d.txt"), "foo.bar\nbaz\n")
      {:ok, result} = Grep.execute(%{pattern: "foo.bar", path: ".", literal: true}, dir)
      assert result =~ "foo.bar"
    end

    @tag :requires_rg
    test "respects limit", %{dir: dir} do
      for i <- 1..20 do
        File.write!(Path.join(dir, "f#{i}.txt"), "match line\n")
      end

      {:ok, result} = Grep.execute(%{pattern: "match", path: ".", limit: 5}, dir)
      lines = result |> String.split("\n") |> Enum.reject(&String.starts_with?(&1, "("))
      assert length(lines) <= 5
    end

    @tag :requires_rg
    test "glob filter restricts searched files", %{dir: dir} do
      File.write!(Path.join(dir, "code.ex"), "hello from elixir\n")
      File.write!(Path.join(dir, "notes.txt"), "hello from text\n")
      {:ok, result} = Grep.execute(%{pattern: "hello", path: ".", glob: "*.ex"}, dir)
      assert result =~ "code.ex"
      refute result =~ "notes.txt"
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Grep.execute(%{pattern: "foo", path: "../outside"}, dir)
    end

    test "returns error when rg is not available" do
      # This test validates the error path; when rg IS available, PathGuard will
      # reject the outside-root path before the rg check. Test the rg-missing branch
      # directly by confirming execute returns an error when rg is absent on this machine.
      if is_nil(System.find_executable("rg")) do
        dir = System.tmp_dir!()
        assert {:error, msg} = Grep.execute(%{pattern: "foo", path: "."}, dir)
        assert msg =~ "rg"
      end
    end
  end
end
