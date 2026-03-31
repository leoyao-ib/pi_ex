defmodule PiEx.DeepAgent.Tools.WriteTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Write

  setup do
    dir = System.tmp_dir!() |> Path.join("write_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    test "writes content to a new file", %{dir: dir} do
      {:ok, msg} = Write.execute(%{path: "new_file.txt", content: "hello"}, dir)
      assert msg =~ "Wrote"
      assert File.read!(Path.join(dir, "new_file.txt")) == "hello"
    end

    test "overwrites existing file", %{dir: dir} do
      path = Path.join(dir, "existing.txt")
      File.write!(path, "old content")
      {:ok, _msg} = Write.execute(%{path: "existing.txt", content: "new content"}, dir)
      assert File.read!(path) == "new content"
    end

    test "creates parent directories as needed", %{dir: dir} do
      {:ok, _msg} = Write.execute(%{path: "a/b/c/deep.txt", content: "deep"}, dir)
      assert File.read!(Path.join(dir, "a/b/c/deep.txt")) == "deep"
    end

    test "returns bytes written", %{dir: dir} do
      content = "hello world"
      {:ok, msg} = Write.execute(%{path: "bytes.txt", content: content}, dir)
      assert msg =~ "#{byte_size(content)} bytes"
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Write.execute(%{path: "../outside.txt", content: "evil"}, dir)
    end
  end
end
