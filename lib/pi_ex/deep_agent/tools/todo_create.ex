defmodule PiEx.DeepAgent.Tools.TodoCreate do
  @moduledoc "LLM tool: create a new todo item in the agent's in-memory todo list."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.TodoStore

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `list_id`."
  @spec tool(String.t()) :: Tool.t()
  def tool(list_id) do
    %Tool{
      name: "todo_create",
      label: "Create Todo",
      description:
        "Create a new todo item with a title and optional description. Status starts as pending.",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "title" => %{
            "type" => "string",
            "description" => "Short title for the todo item."
          },
          "description" => %{
            "type" => "string",
            "description" => "Optional longer description of the task."
          }
        },
        "required" => ["title"]
      },
      execute: fn _call_id, params, _opts ->
        title = Map.fetch!(params, "title")
        description = Map.get(params, "description", "")

        case execute(%{title: title, description: description}, list_id) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the create operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, list_id) do
    title = Map.fetch!(params, :title)
    description = Map.get(params, :description, "")

    case TodoStore.create(list_id, title, description) do
      {:ok, item} ->
        {:ok, "Created todo [#{item.id}]: #{item.title} (status: #{item.status})"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
