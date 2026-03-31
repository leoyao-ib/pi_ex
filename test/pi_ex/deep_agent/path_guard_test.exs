defmodule PiEx.DeepAgent.PathGuardTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.PathGuard

  @root "/home/user/project"

  describe "resolve/2" do
    test "valid relative path inside root" do
      assert {:ok, "/home/user/project/src/main.ex"} =
               PathGuard.resolve(@root, "src/main.ex")
    end

    test "valid nested relative path" do
      assert {:ok, "/home/user/project/a/b/c.txt"} =
               PathGuard.resolve(@root, "a/b/c.txt")
    end

    test "root itself is allowed" do
      assert {:ok, @root} = PathGuard.resolve(@root, ".")
    end

    test "path traversal is rejected" do
      assert {:error, "path is outside project root"} =
               PathGuard.resolve(@root, "../outside/file.txt")
    end

    test "absolute path outside root is rejected" do
      assert {:error, "path is outside project root"} =
               PathGuard.resolve(@root, "/etc/passwd")
    end

    test "absolute path inside root is allowed" do
      assert {:ok, "/home/user/project/src/file.ex"} =
               PathGuard.resolve(@root, "/home/user/project/src/file.ex")
    end

    test "path equal to root with trailing slash is rejected" do
      # "/home/user/project/" expands to "/home/user/project" == root → allowed
      assert {:ok, @root} = PathGuard.resolve(@root, "./")
    end

    test "sibling directory is rejected" do
      assert {:error, "path is outside project root"} =
               PathGuard.resolve(@root, "../other_project/file.ex")
    end

    test "path that begins with root string but is not inside it" do
      # "/home/user/project_evil" starts with "/home/user/project" but is NOT inside it
      assert {:error, "path is outside project root"} =
               PathGuard.resolve(@root, "/home/user/project_evil/file.ex")
    end
  end
end
