defmodule PiEx.DeepAgent.Tools.Find do
  @moduledoc "LLM tool: find files by glob pattern using ripgrep (rg)."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.PathGuard

  @default_limit 1000

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `project_root`."
  @spec tool(String.t()) :: Tool.t()
  def tool(project_root) do
    %Tool{
      name: "find",
      label: "Find Files",
      description: """
      Find files matching a glob pattern. Uses ripgrep which respects .gitignore.
      Falls back to Path.wildcard if rg is not installed (no .gitignore filtering).
      Returns paths relative to the search directory.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "pattern" => %{
            "type" => "string",
            "description" => "Glob pattern to match files (e.g. \"**/*.ex\")."
          },
          "path" => %{
            "type" => "string",
            "description" =>
              "Directory to search in (relative to project root). Defaults to project root."
          },
          "limit" => %{
            "type" => "integer",
            "description" => "Maximum number of results. Default #{@default_limit}."
          }
        },
        "required" => ["pattern"]
      },
      execute: fn _call_id, params, _opts ->
        pattern = Map.fetch!(params, "pattern")
        path = Map.get(params, "path", ".")
        limit = Map.get(params, "limit", @default_limit)

        case execute(%{pattern: pattern, path: path, limit: limit}, project_root) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the find operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, project_root) do
    pattern = Map.fetch!(params, :pattern)
    path = Map.get(params, :path, ".")
    limit = Map.get(params, :limit, @default_limit)

    with {:ok, abs_path} <- PathGuard.resolve(project_root, path) do
      paths = find_files(pattern, abs_path)

      limited =
        if length(paths) > limit do
          kept = Enum.take(paths, limit)
          kept ++ ["(#{length(paths) - limit} more results not shown)"]
        else
          paths
        end

      {:ok, Enum.join(limited, "\n")}
    end
  end

  defp find_files(pattern, abs_path) do
    if rg_available?() do
      case System.cmd("rg", ["--files", "--glob", pattern, abs_path],
             stderr_to_stdout: false,
             cd: abs_path
           ) do
        {output, _} ->
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&make_relative(&1, abs_path))
      end
    else
      fallback_find(pattern, abs_path)
    end
  end

  defp fallback_find(pattern, abs_path) do
    abs_path
    |> Path.join(pattern)
    |> Path.wildcard()
    |> Enum.map(&make_relative(&1, abs_path))
  end

  defp make_relative(path, base) do
    case String.split(path, base <> "/", parts: 2) do
      [_, relative] -> relative
      _ -> path
    end
  end

  defp rg_available? do
    case System.find_executable("rg") do
      nil -> false
      _ -> true
    end
  end
end
