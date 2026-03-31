defmodule PiEx.DeepAgent.Tools.Edit do
  @moduledoc "LLM tool: apply text edits to a file and return a unified diff."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.{FileMutex, PathGuard}
  alias PiEx.DeepAgent.Tools.EditDiff

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `project_root`."
  @spec tool(String.t()) :: Tool.t()
  def tool(project_root) do
    %Tool{
      name: "edit",
      label: "Edit File",
      description: """
      Apply one or more edits to a file by replacing old_text with new_text.
      All edits are matched against the original file content (not applied sequentially).
      Returns a unified diff of the changes.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "path" => %{
            "type" => "string",
            "description" => "File path to edit (relative to project root)."
          },
          "edits" => %{
            "type" => "array",
            "description" => "List of edit operations.",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "old_text" => %{"type" => "string", "description" => "Text to replace."},
                "new_text" => %{"type" => "string", "description" => "Replacement text."}
              },
              "required" => ["old_text", "new_text"]
            }
          }
        },
        "required" => ["path", "edits"]
      },
      execute: fn _call_id, params, _opts ->
        path = Map.fetch!(params, "path")

        edits =
          Enum.map(params["edits"] || [], fn e ->
            %{old_text: e["old_text"], new_text: e["new_text"]}
          end)

        case execute(%{path: path, edits: edits}, project_root) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the edit operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, project_root) do
    path = Map.fetch!(params, :path)
    edits = Map.fetch!(params, :edits)

    with {:ok, abs_path} <- PathGuard.resolve(project_root, path) do
      result =
        FileMutex.with_lock(abs_path, fn ->
          with {:ok, old_content} <- safe_read(abs_path),
               {:ok, new_content} <- EditDiff.apply_edits(old_content, edits) do
            File.write!(abs_path, new_content)
            diff = EditDiff.generate_diff(old_content, new_content, abs_path)
            {:ok, diff}
          end
        end)

      case result do
        {:ok, diff} -> {:ok, diff}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp safe_read(abs_path) do
    case File.read(abs_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, "File not found: #{abs_path}"}
      {:error, reason} -> {:error, "Cannot read file: #{reason}"}
    end
  end
end
