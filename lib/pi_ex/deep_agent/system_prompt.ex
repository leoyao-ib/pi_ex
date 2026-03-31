defmodule PiEx.DeepAgent.SystemPrompt do
  @moduledoc "Builds the default system prompt for `PiEx.DeepAgent`."

  @doc """
  Build a system prompt string from a list of tools and optional extra content.

  Options:
  - `:append_system_prompt` — string appended at the end
  """
  @spec build([PiEx.Agent.Tool.t()], keyword()) :: String.t()
  def build(tools, opts \\ []) do
    append = Keyword.get(opts, :append_system_prompt, "")

    tool_section =
      tools
      |> Enum.map(fn t ->
        "- **#{t.name}**: #{String.trim(t.description)}"
      end)
      |> Enum.join("\n")

    base = """
    You are a general-purpose AI agent with access to tools that let you read and modify
    a software project. You operate within a sandboxed project directory and all file paths
    are relative to the project root.

    ## Available tools

    #{tool_section}

    ## Guidelines

    - Prefer `read`, `grep`, and `find` for discovery before making changes.
    - All paths must be relative to the project root.
    - Avoid unnecessary writes; only write when explicitly required.
    - When editing, use the `edit` tool rather than rewriting entire files.
    - Always verify a file exists before attempting to edit it.
    """

    if append != "" do
      String.trim_trailing(base) <> "\n\n" <> append
    else
      base
    end
  end
end
