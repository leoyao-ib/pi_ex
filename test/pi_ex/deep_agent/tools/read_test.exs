defmodule PiEx.DeepAgent.Tools.ReadTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Read

  setup do
    dir = System.tmp_dir!() |> Path.join("read_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    test "reads file with line numbers", %{dir: dir} do
      File.write!(Path.join(dir, "file.txt"), "line one\nline two\nline three")
      {:ok, result} = Read.execute(%{path: "file.txt"}, dir)
      assert result =~ "line one"
      assert result =~ "line two"
      assert result =~ "line three"
      # Check line number format
      assert result =~ "| line one"
    end

    test "respects offset (1-indexed)", %{dir: dir} do
      content = Enum.map_join(1..5, "\n", &"line #{&1}")
      File.write!(Path.join(dir, "file.txt"), content)
      {:ok, result} = Read.execute(%{path: "file.txt", offset: 3}, dir)
      refute result =~ "line 1"
      refute result =~ "line 2"
      assert result =~ "line 3"
    end

    test "respects limit", %{dir: dir} do
      content = Enum.map_join(1..10, "\n", &"line #{&1}")
      File.write!(Path.join(dir, "file.txt"), content)
      {:ok, result} = Read.execute(%{path: "file.txt", limit: 3}, dir)
      lines = String.split(result, "\n")
      assert length(lines) == 3
    end

    test "offset and limit together", %{dir: dir} do
      content = Enum.map_join(1..10, "\n", &"line #{&1}")
      File.write!(Path.join(dir, "file.txt"), content)
      {:ok, result} = Read.execute(%{path: "file.txt", offset: 3, limit: 2}, dir)
      assert result =~ "line 3"
      assert result =~ "line 4"
      refute result =~ "line 5"
    end

    test "returns error for non-existent file", %{dir: dir} do
      assert {:error, _reason} = Read.execute(%{path: "missing.txt"}, dir)
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Read.execute(%{path: "../outside.txt"}, dir)
    end
  end
end
