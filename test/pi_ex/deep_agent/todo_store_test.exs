defmodule PiEx.DeepAgent.TodoStoreTest do
  use ExUnit.Case, async: false

  alias PiEx.DeepAgent.TodoStore

  defp unique_list_id, do: "test_list_#{:erlang.unique_integer([:positive])}"

  describe "create/3" do
    test "creates item with pending status and returns it" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Buy milk")
      assert item.title == "Buy milk"
      assert item.status == :pending
      assert item.description == ""
      assert is_binary(item.id)
      assert %DateTime{} = item.created_at
    end

    test "creates item with description" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Deploy app", "Deploy to production")
      assert item.description == "Deploy to production"
    end

    test "multiple creates produce distinct IDs" do
      list_id = unique_list_id()
      {:ok, a} = TodoStore.create(list_id, "Task A")
      {:ok, b} = TodoStore.create(list_id, "Task B")
      refute a.id == b.id
    end
  end

  describe "list/1" do
    test "returns empty list for unknown list_id" do
      assert TodoStore.list("nonexistent_list") == []
    end

    test "returns all items for the list_id" do
      list_id = unique_list_id()
      {:ok, _} = TodoStore.create(list_id, "Task 1")
      {:ok, _} = TodoStore.create(list_id, "Task 2")
      items = TodoStore.list(list_id)
      assert length(items) == 2
      titles = Enum.map(items, & &1.title)
      assert "Task 1" in titles
      assert "Task 2" in titles
    end

    test "does not return items from other list_ids" do
      list_a = unique_list_id()
      list_b = unique_list_id()
      {:ok, _} = TodoStore.create(list_a, "Only in A")
      items = TodoStore.list(list_b)
      assert items == []
    end

    test "returns items sorted by created_at" do
      list_id = unique_list_id()
      {:ok, _} = TodoStore.create(list_id, "First")
      Process.sleep(2)
      {:ok, _} = TodoStore.create(list_id, "Second")
      [a, b] = TodoStore.list(list_id)
      assert a.title == "First"
      assert b.title == "Second"
    end
  end

  describe "update/3" do
    test "updates status to in_progress" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      {:ok, updated} = TodoStore.update(list_id, item.id, %{"status" => "in_progress"})
      assert updated.status == :in_progress
    end

    test "updates status to done" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      {:ok, updated} = TodoStore.update(list_id, item.id, %{"status" => "done"})
      assert updated.status == :done
    end

    test "updates status to cancelled" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      {:ok, updated} = TodoStore.update(list_id, item.id, %{"status" => "cancelled"})
      assert updated.status == :cancelled
    end

    test "updates title" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Old title")
      {:ok, updated} = TodoStore.update(list_id, item.id, %{"title" => "New title"})
      assert updated.title == "New title"
    end

    test "updates description" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      {:ok, updated} = TodoStore.update(list_id, item.id, %{"description" => "New desc"})
      assert updated.description == "New desc"
    end

    test "updates multiple fields at once" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")

      {:ok, updated} =
        TodoStore.update(list_id, item.id, %{"status" => "done", "title" => "Done Task"})

      assert updated.status == :done
      assert updated.title == "Done Task"
    end

    test "returns error for unknown item_id" do
      list_id = unique_list_id()
      assert {:error, msg} = TodoStore.update(list_id, "no_such_id", %{"status" => "done"})
      assert msg =~ "not found"
    end

    test "returns error for invalid status string" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      assert {:error, msg} = TodoStore.update(list_id, item.id, %{"status" => "flying"})
      assert msg =~ "invalid status"
    end

    test "returns error for unknown field" do
      list_id = unique_list_id()
      {:ok, item} = TodoStore.create(list_id, "Task")
      assert {:error, msg} = TodoStore.update(list_id, item.id, %{"unknown_field" => "val"})
      assert msg =~ "unknown field"
    end
  end

  describe "delete_list/1" do
    test "removes all items for the list_id" do
      list_id = unique_list_id()
      {:ok, _} = TodoStore.create(list_id, "Task 1")
      {:ok, _} = TodoStore.create(list_id, "Task 2")
      :ok = TodoStore.delete_list(list_id)
      assert TodoStore.list(list_id) == []
    end

    test "does not affect items from other list_ids" do
      list_a = unique_list_id()
      list_b = unique_list_id()
      {:ok, _} = TodoStore.create(list_a, "A task")
      {:ok, _} = TodoStore.create(list_b, "B task")
      :ok = TodoStore.delete_list(list_a)
      assert length(TodoStore.list(list_b)) == 1
    end

    test "is a no-op for non-existent list_id" do
      assert :ok = TodoStore.delete_list("nonexistent_#{unique_list_id()}")
    end
  end
end
