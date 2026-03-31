defmodule PiEx.DeepAgent.Tools.LsTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Ls

  setup do
    dir = System.tmp_dir!() |> Path.join("ls_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    test "lists files in directory", %{dir: dir} do
      File.write!(Path.join(dir, "foo.ex"), "")
      File.write!(Path.join(dir, "bar.ex"), "")
      {:ok, result} = Ls.execute(%{path: "."}, dir)
      assert result =~ "bar.ex"
      assert result =~ "foo.ex"
    end

    test "appends / to directories", %{dir: dir} do
      File.mkdir_p!(Path.join(dir, "subdir"))
      {:ok, result} = Ls.execute(%{path: "."}, dir)
      assert result =~ "subdir/"
    end

    test "sorts entries alphabetically", %{dir: dir} do
      File.write!(Path.join(dir, "z.txt"), "")
      File.write!(Path.join(dir, "a.txt"), "")
      {:ok, result} = Ls.execute(%{path: "."}, dir)
      lines = String.split(result, "\n")
      assert Enum.at(lines, 0) == "a.txt"
      assert Enum.at(lines, 1) == "z.txt"
    end

    test "respects limit", %{dir: dir} do
      for i <- 1..10, do: File.write!(Path.join(dir, "file#{i}.txt"), "")
      {:ok, result} = Ls.execute(%{path: ".", limit: 3}, dir)
      lines = result |> String.split("\n") |> Enum.reject(&String.starts_with?(&1, "("))
      assert length(lines) == 3
      assert result =~ "more entries not shown"
    end

    test "filters .gitignore patterns", %{dir: dir} do
      File.write!(Path.join(dir, "keep.ex"), "")
      File.write!(Path.join(dir, "ignore.log"), "")
      File.write!(Path.join(dir, ".gitignore"), "*.log\n")
      {:ok, result} = Ls.execute(%{path: "."}, dir)
      assert result =~ "keep.ex"
      refute result =~ "ignore.log"
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Ls.execute(%{path: "../outside"}, dir)
    end

    test "returns error for non-existent directory", %{dir: dir} do
      assert {:error, _reason} = Ls.execute(%{path: "nonexistent"}, dir)
    end
  end
end
