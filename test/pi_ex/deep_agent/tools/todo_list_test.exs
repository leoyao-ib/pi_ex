defmodule PiEx.DeepAgent.Tools.TodoListTest do
  use ExUnit.Case, async: false

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.Tools.TodoList
  alias PiEx.DeepAgent.TodoStore

  defp unique_list_id, do: "tl_test_#{:erlang.unique_integer([:positive])}"

  describe "execute/2" do
    test "returns 'No todo items found.' for empty list" do
      list_id = unique_list_id()
      {:ok, text} = TodoList.execute(%{}, list_id)
      assert text == "No todo items found."
    end

    test "returns all items when no status_filter" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task A")
      TodoStore.update(list_id, item.id, %{"status" => "done"})
      {:ok, _} = TodoStore.create(list_id, "Task B")
      {:ok, text} = TodoList.execute(%{}, list_id)
      assert text =~ "Task A"
      assert text =~ "Task B"
    end

    test "filters by status when status_filter provided" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Finished")
      TodoStore.update(list_id, item.id, %{"status" => "done"})
      {:ok, _} = TodoStore.create(list_id, "Still pending")
      {:ok, text} = TodoList.execute(%{status_filter: "done"}, list_id)
      assert text =~ "Finished"
      refute text =~ "Still pending"
    end

    test "returns 'No todo items found.' when filter matches nothing" do
      list_id = unique_list_id()
      {:ok, _} = TodoStore.create(list_id, "Pending task")
      {:ok, text} = TodoList.execute(%{status_filter: "done"}, list_id)
      assert text == "No todo items found."
    end

    test "items from other list_ids are not visible" do
      list_a = unique_list_id()
      list_b = unique_list_id()
      {:ok, _} = TodoStore.create(list_a, "Only in A")
      {:ok, text} = TodoList.execute(%{}, list_b)
      assert text == "No todo items found."
    end

    test "includes description in output when present" do
      list_id = unique_list_id()
      {:ok, _} = TodoStore.create(list_id, "Task", "Some details")
      {:ok, text} = TodoList.execute(%{}, list_id)
      assert text =~ "Some details"
    end
  end

  describe "tool/1" do
    test "returns %Tool{} with name 'todo_list'" do
      tool = TodoList.tool(unique_list_id())
      assert %Tool{name: "todo_list"} = tool
    end

    test "execute closure returns {:ok, %{content: [%TextContent{}], details: nil}}" do
      list_id = unique_list_id()
      tool = TodoList.tool(list_id)
      result = tool.execute.("call_1", %{}, [])
      assert {:ok, %{content: [%TextContent{}], details: nil}} = result
    end
  end
end
