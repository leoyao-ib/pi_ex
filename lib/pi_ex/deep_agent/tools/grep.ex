defmodule PiEx.DeepAgent.Tools.Grep do
  @moduledoc "LLM tool: search file contents using ripgrep."

  alias PiEx.Agent.Tool
  alias PiEx.AI.Content.TextContent
  alias PiEx.DeepAgent.PathGuard
  alias PiEx.DeepAgent.Tools.Truncate

  @default_limit 500

  @doc "Build a `%PiEx.Agent.Tool{}` scoped to `project_root`."
  @spec tool(String.t()) :: Tool.t()
  def tool(project_root) do
    %Tool{
      name: "grep",
      label: "Search Files",
      description: """
      Search file contents using ripgrep. Returns matching lines as \"file:line: content\".
      Supports case-insensitive search, literal string matching, context lines, glob filtering, and result limits.
      Requires `rg` (ripgrep) to be installed.
      """,
      parameters: %{
        "type" => "object",
        "properties" => %{
          "pattern" => %{
            "type" => "string",
            "description" => "Regex pattern (or literal string if literal: true) to search for."
          },
          "path" => %{
            "type" => "string",
            "description" => "Directory or file to search in (relative to project root). Defaults to project root."
          },
          "glob" => %{
            "type" => "string",
            "description" => "Glob pattern to filter files (e.g. \"*.ex\")."
          },
          "ignore_case" => %{
            "type" => "boolean",
            "description" => "Case-insensitive search."
          },
          "literal" => %{
            "type" => "boolean",
            "description" => "Treat pattern as a literal string, not a regex."
          },
          "context" => %{
            "type" => "integer",
            "description" => "Number of context lines before and after each match."
          },
          "limit" => %{
            "type" => "integer",
            "description" => "Maximum number of matching lines to return. Default #{@default_limit}."
          }
        },
        "required" => ["pattern"]
      },
      execute: fn _call_id, params, _opts ->
        pattern = Map.fetch!(params, "pattern")
        path = Map.get(params, "path", ".")
        glob = Map.get(params, "glob")
        ignore_case = Map.get(params, "ignore_case", false)
        literal = Map.get(params, "literal", false)
        context = Map.get(params, "context")
        limit = Map.get(params, "limit", @default_limit)

        case execute(
               %{
                 pattern: pattern,
                 path: path,
                 glob: glob,
                 ignore_case: ignore_case,
                 literal: literal,
                 context: context,
                 limit: limit
               },
               project_root
             ) do
          {:ok, text} -> {:ok, %{content: [%TextContent{text: text}], details: nil}}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc "Execute the grep operation directly (for testing)."
  @spec execute(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(params, project_root) do
    pattern = Map.fetch!(params, :pattern)
    path = Map.get(params, :path, ".")
    glob = Map.get(params, :glob)
    ignore_case = Map.get(params, :ignore_case, false)
    literal = Map.get(params, :literal, false)
    context = Map.get(params, :context)
    limit = Map.get(params, :limit, @default_limit)

    with {:ok, abs_path} <- PathGuard.resolve(project_root, path),
         :ok <- check_rg_available() do
      args = build_args(pattern, abs_path, glob, ignore_case, literal, context)

      case System.cmd("rg", args, stderr_to_stdout: false) do
        {output, exit_code} when exit_code in [0, 1] ->
          lines =
            output
            |> String.split("\n", trim: true)
            |> Enum.map(&Truncate.truncate_line(&1, Truncate.grep_max_line_length()))

          {result_lines, notice} =
            if length(lines) > limit do
              {Enum.take(lines, limit),
               "\n(#{length(lines) - limit} more results not shown, use limit to increase)"}
            else
              {lines, ""}
            end

          {:ok, Enum.join(result_lines, "\n") <> notice}

        {output, _exit_code} ->
          {:error, "rg failed: #{output}"}
      end
    end
  end

  defp build_args(pattern, abs_path, glob, ignore_case, literal, context) do
    base = ["--no-heading", "--line-number", "--color=never"]

    base
    |> maybe_add(ignore_case, "--ignore-case")
    |> maybe_add(literal, "--fixed-strings")
    |> maybe_add_context(context)
    |> maybe_add_glob(glob)
    |> Kernel.++([pattern, abs_path])
  end

  defp maybe_add(args, true, flag), do: args ++ [flag]
  defp maybe_add(args, _, _flag), do: args

  defp maybe_add_context(args, n) when is_integer(n) and n > 0 do
    args ++ ["--before-context", to_string(n), "--after-context", to_string(n)]
  end

  defp maybe_add_context(args, _), do: args

  defp maybe_add_glob(args, glob) when is_binary(glob) and glob != "" do
    args ++ ["--glob", glob]
  end

  defp maybe_add_glob(args, _), do: args

  defp check_rg_available do
    case System.find_executable("rg") do
      nil -> {:error, "rg (ripgrep) is not installed or not in PATH"}
      _ -> :ok
    end
  end
end
