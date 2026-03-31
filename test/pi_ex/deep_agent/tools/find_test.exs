defmodule PiEx.DeepAgent.Tools.FindTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Find

  setup do
    dir = System.tmp_dir!() |> Path.join("find_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    test "finds files by glob pattern", %{dir: dir} do
      File.write!(Path.join(dir, "hello.ex"), "")
      File.write!(Path.join(dir, "world.exs"), "")
      File.write!(Path.join(dir, "readme.md"), "")
      {:ok, result} = Find.execute(%{pattern: "*.ex", path: "."}, dir)
      assert result =~ "hello.ex"
      refute result =~ "readme.md"
    end

    test "finds files in subdirectories", %{dir: dir} do
      sub = Path.join(dir, "lib")
      File.mkdir_p!(sub)
      File.write!(Path.join(sub, "deep.ex"), "")
      {:ok, result} = Find.execute(%{pattern: "**/*.ex", path: "."}, dir)
      assert result =~ "deep.ex"
    end

    test "respects limit", %{dir: dir} do
      for i <- 1..10, do: File.write!(Path.join(dir, "file#{i}.txt"), "")
      {:ok, result} = Find.execute(%{pattern: "*.txt", path: ".", limit: 3}, dir)
      lines = result |> String.split("\n") |> Enum.reject(&String.starts_with?(&1, "("))
      assert length(lines) == 3
      assert result =~ "more results not shown"
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Find.execute(%{pattern: "*.ex", path: "../outside"}, dir)
    end

    test "returns empty string when no files match", %{dir: dir} do
      {:ok, result} = Find.execute(%{pattern: "*.xyz", path: "."}, dir)
      assert result == ""
    end
  end
end
