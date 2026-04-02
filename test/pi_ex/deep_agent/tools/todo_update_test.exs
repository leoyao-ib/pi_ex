defmodule PiEx.DeepAgent.Tools.TodoUpdateTest do
  use ExUnit.Case, async: false

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.Tools.TodoUpdate
  alias PiEx.DeepAgent.TodoStore

  defp unique_list_id, do: "tu_test_#{:erlang.unique_integer([:positive])}"

  defp create_item(list_id, title \\ "Sample task") do
    {:ok, item} = TodoStore.create(list_id, title)
    item
  end

  describe "execute/2" do
    test "updates status" do
      list_id = unique_list_id()
      item = create_item(list_id)

      {:ok, msg} =
        TodoUpdate.execute(%{id: item.id, changes: %{"status" => "in_progress"}}, list_id)

      assert msg =~ "Updated todo"
      assert msg =~ "in_progress"
    end

    test "updates title" do
      list_id = unique_list_id()
      item = create_item(list_id)
      {:ok, msg} = TodoUpdate.execute(%{id: item.id, changes: %{"title" => "New title"}}, list_id)
      assert msg =~ "New title"
    end

    test "updates description" do
      list_id = unique_list_id()
      item = create_item(list_id)

      {:ok, _} =
        TodoUpdate.execute(%{id: item.id, changes: %{"description" => "New desc"}}, list_id)

      [updated] = TodoStore.list(list_id)
      assert updated.description == "New desc"
    end

    test "returns error for unknown item_id" do
      list_id = unique_list_id()

      assert {:error, msg} =
               TodoUpdate.execute(%{id: "no_such", changes: %{"status" => "done"}}, list_id)

      assert msg =~ "not found"
    end

    test "returns error when no changes provided" do
      list_id = unique_list_id()
      item = create_item(list_id)
      assert {:error, msg} = TodoUpdate.execute(%{id: item.id, changes: %{}}, list_id)
      assert msg =~ "at least one"
    end

    test "returns error for invalid status" do
      list_id = unique_list_id()
      item = create_item(list_id)

      assert {:error, msg} =
               TodoUpdate.execute(%{id: item.id, changes: %{"status" => "invalid"}}, list_id)

      assert msg =~ "invalid status"
    end
  end

  describe "tool/1" do
    test "returns %Tool{} with name 'todo_update'" do
      tool = TodoUpdate.tool(unique_list_id())
      assert %Tool{name: "todo_update"} = tool
    end

    test "execute closure returns {:ok, %{content: [%TextContent{}], details: nil}}" do
      list_id = unique_list_id()
      item = create_item(list_id)
      tool = TodoUpdate.tool(list_id)
      result = tool.execute.("call_1", %{"id" => item.id, "status" => "done"}, [])
      assert {:ok, %{content: [%TextContent{}], details: nil}} = result
    end
  end
end
