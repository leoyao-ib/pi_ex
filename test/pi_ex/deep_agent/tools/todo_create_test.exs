defmodule PiEx.DeepAgent.Tools.TodoCreateTest do
  use ExUnit.Case, async: false

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.Tools.TodoCreate
  alias PiEx.DeepAgent.TodoStore

  defp unique_list_id, do: "tc_test_#{:erlang.unique_integer([:positive])}"

  describe "execute/2" do
    test "creates item and returns confirmation message" do
      list_id = unique_list_id()
      {:ok, msg} = TodoCreate.execute(%{title: "Write tests"}, list_id)
      assert msg =~ "Created todo"
      assert msg =~ "Write tests"
      assert msg =~ "pending"
    end

    test "created item appears in TodoStore.list/1" do
      list_id = unique_list_id()
      {:ok, _} = TodoCreate.execute(%{title: "Persisted task"}, list_id)
      [item] = TodoStore.list(list_id)
      assert item.title == "Persisted task"
    end

    test "description defaults to empty string when not provided" do
      list_id = unique_list_id()
      {:ok, _} = TodoCreate.execute(%{title: "No desc"}, list_id)
      [item] = TodoStore.list(list_id)
      assert item.description == ""
    end

    test "description is stored when provided" do
      list_id = unique_list_id()
      {:ok, _} = TodoCreate.execute(%{title: "With desc", description: "Details here"}, list_id)
      [item] = TodoStore.list(list_id)
      assert item.description == "Details here"
    end
  end

  describe "tool/1" do
    test "returns %Tool{} with name 'todo_create'" do
      tool = TodoCreate.tool(unique_list_id())
      assert %Tool{name: "todo_create"} = tool
    end

    test "execute closure returns {:ok, %{content: [%TextContent{}], details: nil}}" do
      list_id = unique_list_id()
      tool = TodoCreate.tool(list_id)
      result = tool.execute.("call_1", %{"title" => "My task"}, [])
      assert {:ok, %{content: [%TextContent{text: text}], details: nil}} = result
      assert text =~ "My task"
    end

    test "execute closure uses the captured list_id" do
      list_id = unique_list_id()
      tool = TodoCreate.tool(list_id)
      tool.execute.("call_1", %{"title" => "Isolated task"}, [])
      assert length(TodoStore.list(list_id)) == 1
    end
  end
end
