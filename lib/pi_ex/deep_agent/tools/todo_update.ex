defmodule PiEx.DeepAgent.Tools.TodoUpdate do
  @moduledoc "LLM tool: update a todo item's status, title, or description."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.TodoStore

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `list_id`."
  @spec tool(String.t()) :: Tool.t()
  def tool(list_id) do
    %Tool{
      name: "todo_update",
      label: "Update Todo",
      description: """
      Update a todo item's status, title, or description.
      At least one of status, title, or description must be provided.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "description" => "The todo item ID (from todo_create or todo_list)."
          },
          "status" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "done", "cancelled"],
            "description" => "New status for the item."
          },
          "title" => %{
            "type" => "string",
            "description" => "New title for the item."
          },
          "description" => %{
            "type" => "string",
            "description" => "New description for the item."
          }
        },
        "required" => ["id"]
      },
      execute: fn _call_id, params, _opts ->
        item_id = Map.fetch!(params, "id")
        changes = Map.take(params, ["status", "title", "description"])

        case execute(%{id: item_id, changes: changes}, list_id) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the update operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, list_id) do
    item_id = Map.fetch!(params, :id)
    changes = Map.get(params, :changes, %{})

    if map_size(changes) == 0 do
      {:error, "at least one of: status, title, description must be provided"}
    else
      case TodoStore.update(list_id, item_id, changes) do
        {:ok, item} ->
          {:ok, "Updated todo [#{item.id}]: #{item.title} (status: #{item.status})"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
