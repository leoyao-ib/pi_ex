defmodule PiEx.DeepAgent.Tools.Write do
  @moduledoc "LLM tool: write content to a file, creating parent directories as needed."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.{FileMutex, PathGuard}

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `project_root`."
  @spec tool(String.t()) :: Tool.t()
  def tool(project_root) do
    %Tool{
      name: "write",
      label: "Write File",
      description: """
      Write content to a file, creating parent directories as needed.
      Overwrites any existing file at the path.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "path" => %{
            "type" => "string",
            "description" => "File path to write to (relative to project root)."
          },
          "content" => %{
            "type" => "string",
            "description" => "Content to write to the file."
          }
        },
        "required" => ["path", "content"]
      },
      execute: fn _call_id, params, _opts ->
        path = Map.fetch!(params, "path")
        content = Map.fetch!(params, "content")

        case execute(%{path: path, content: content}, project_root) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the write operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, project_root) do
    path = Map.fetch!(params, :path)
    content = Map.fetch!(params, :content)

    with {:ok, abs_path} <- PathGuard.resolve(project_root, path) do
      result =
        FileMutex.with_lock(abs_path, fn ->
          :ok = File.mkdir_p!(Path.dirname(abs_path))
          File.write!(abs_path, content)
          byte_size(content)
        end)

      case result do
        bytes when is_integer(bytes) ->
          {:ok, "Wrote #{bytes} bytes to #{path}"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
