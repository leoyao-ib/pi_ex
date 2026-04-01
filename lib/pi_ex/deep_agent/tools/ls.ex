defmodule PiEx.DeepAgent.Tools.Ls do
  @moduledoc "LLM tool: list directory contents, filtered by .gitignore."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.PathGuard

  @default_limit 500

  @doc "Build a `%PiEx.Agent.Tool{}` for this tool scoped to `project_root`."
  @spec tool(String.t()) :: Tool.t()
  def tool(project_root) do
    %Tool{
      name: "ls",
      label: "List Directory",
      description: """
      List the contents of a directory. Returns file and directory names, with `/` appended to directories.
      Filters entries matching .gitignore patterns. Defaults to the project root if no path is given.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "path" => %{
            "type" => "string",
            "description" =>
              "Directory path to list (relative to project root). Defaults to project root."
          },
          "limit" => %{
            "type" => "integer",
            "description" => "Maximum number of entries to return. Default #{@default_limit}."
          }
        },
        "required" => []
      },
      execute: fn _call_id, params, _opts ->
        path = Map.get(params, "path", ".")
        limit = Map.get(params, "limit", @default_limit)

        case execute(%{path: path, limit: limit}, project_root) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the ls operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, project_root) do
    path = Map.get(params, :path, ".")
    limit = Map.get(params, :limit, @default_limit)

    with {:ok, abs_path} <- PathGuard.resolve(project_root, path),
         {:ok, entries} <- list_entries(abs_path, project_root) do
      result =
        entries
        |> Enum.sort()
        |> apply_limit(limit)

      {:ok, result}
    end
  end

  defp list_entries(abs_path, project_root) do
    case File.ls(abs_path) do
      {:ok, names} ->
        gitignore_patterns = read_gitignore(project_root)

        entries =
          names
          |> Enum.reject(&ignored?(&1, gitignore_patterns))
          |> Enum.map(fn name ->
            full = Path.join(abs_path, name)
            if File.dir?(full), do: name <> "/", else: name
          end)

        {:ok, entries}

      {:error, reason} ->
        {:error, "Cannot list directory: #{reason}"}
    end
  end

  defp read_gitignore(project_root) do
    gitignore_path = Path.join(project_root, ".gitignore")

    case File.read(gitignore_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(String.starts_with?(&1, "#") or &1 == ""))

      {:error, _} ->
        []
    end
  end

  defp ignored?(name, patterns) do
    Enum.any?(patterns, &glob_match?(name, &1))
  end

  defp glob_match?(name, pattern) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", "[^/]*")
      |> String.replace("\\?", "[^/]")
      |> then(&Regex.compile!("^#{&1}$"))

    Regex.match?(regex, name)
  end

  defp apply_limit(entries, limit) when length(entries) > limit do
    kept = Enum.take(entries, limit)
    (kept ++ ["(#{length(entries) - limit} more entries not shown)"]) |> Enum.join("\n")
  end

  defp apply_limit(entries, _limit), do: Enum.join(entries, "\n")
end
