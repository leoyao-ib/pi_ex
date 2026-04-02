defmodule PiEx.DeepAgent.Tools.TodoList do
  @moduledoc "LLM tool: list all todo items in the agent's in-memory todo list."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.TodoStore

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `list_id`."
  @spec tool(String.t()) :: Tool.t()
  def tool(list_id) do
    %Tool{
      name: "todo_list",
      label: "List Todos",
      description: "List all todo items for this agent run, ordered by creation time.",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "status_filter" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "done", "cancelled"],
            "description" => "Optional: only return items with this status."
          }
        },
        "required" => []
      },
      execute: fn _call_id, params, _opts ->
        status_filter = Map.get(params, "status_filter")

        case execute(%{status_filter: status_filter}, list_id) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the list operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, list_id) do
    status_filter = Map.get(params, :status_filter)

    with {:ok, filtered} <- filter_items(TodoStore.list(list_id), status_filter) do
      text =
        case filtered do
          [] -> "No todo items found."
          _ -> filtered |> Enum.map(&format_item/1) |> Enum.join("\n")
        end

      {:ok, text}
    end
  end

  defp filter_items(items, nil), do: {:ok, items}

  defp filter_items(items, status_str) do
    case parse_status(status_str) do
      {:ok, atom} -> {:ok, Enum.filter(items, &(&1.status == atom))}
      {:error, _} = err -> err
    end
  end

  defp parse_status("pending"), do: {:ok, :pending}
  defp parse_status("in_progress"), do: {:ok, :in_progress}
  defp parse_status("done"), do: {:ok, :done}
  defp parse_status("cancelled"), do: {:ok, :cancelled}

  defp parse_status(s) do
    {:error, "invalid status_filter: #{s}. Must be one of: pending, in_progress, done, cancelled"}
  end

  defp format_item(item) do
    desc_part = if item.description != "", do: " \u2014 #{item.description}", else: ""
    "[#{item.id}] [#{item.status}] #{item.title}#{desc_part}"
  end
end
