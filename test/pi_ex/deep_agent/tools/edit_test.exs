defmodule PiEx.DeepAgent.Tools.EditTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Tools.Edit

  setup do
    dir = System.tmp_dir!() |> Path.join("edit_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "execute/2" do
    test "applies an edit and returns a diff", %{dir: dir} do
      File.write!(Path.join(dir, "file.ex"), "hello world\ngoodbye\n")

      {:ok, diff} =
        Edit.execute(
          %{
            path: "file.ex",
            edits: [%{old_text: "hello world", new_text: "hi there"}]
          },
          dir
        )

      assert is_binary(diff)
      assert File.read!(Path.join(dir, "file.ex")) == "hi there\ngoodbye\n"
    end

    test "applies multiple edits", %{dir: dir} do
      File.write!(Path.join(dir, "multi.ex"), "line A\nline B\nline C\n")

      {:ok, _diff} =
        Edit.execute(
          %{
            path: "multi.ex",
            edits: [
              %{old_text: "line A", new_text: "LINE A"},
              %{old_text: "line C", new_text: "LINE C"}
            ]
          },
          dir
        )

      result = File.read!(Path.join(dir, "multi.ex"))
      assert result =~ "LINE A"
      assert result =~ "line B"
      assert result =~ "LINE C"
    end

    test "returns error when old_text not found", %{dir: dir} do
      File.write!(Path.join(dir, "nochange.ex"), "alpha\nbeta\n")

      assert {:error, _reason} =
               Edit.execute(
                 %{
                   path: "nochange.ex",
                   edits: [%{old_text: "gamma", new_text: "delta"}]
                 },
                 dir
               )
    end

    test "returns error for non-existent file", %{dir: dir} do
      assert {:error, _reason} =
               Edit.execute(
                 %{
                   path: "missing.ex",
                   edits: [%{old_text: "x", new_text: "y"}]
                 },
                 dir
               )
    end

    test "rejects path outside project root", %{dir: dir} do
      assert {:error, "path is outside project root"} =
               Edit.execute(
                 %{
                   path: "../outside.ex",
                   edits: [%{old_text: "x", new_text: "y"}]
                 },
                 dir
               )
    end
  end
end
