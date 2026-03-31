defmodule PiEx.DeepAgent do
  @moduledoc """
  Pre-configured agent harness with 6 built-in LLM tools:
  `ls`, `find`, `read`, `grep`, `write`, `edit`.

  All file operations are sandboxed to a `project_root` directory.

  ## Usage

      config = %PiEx.DeepAgent.Config{
        model: %PiEx.AI.Model{provider: :anthropic, model: "claude-opus-4-6"},
        project_root: "/path/to/project"
      }

      {:ok, pid} = PiEx.DeepAgent.start(config)
      PiEx.Agent.prompt(pid, "List the files in the src directory")

  See `PiEx.Agent` for the full interaction API (prompt, subscribe, steer, abort, etc.).
  """

  alias PiEx.DeepAgent.{Config, SystemPrompt}
  alias PiEx.DeepAgent.Tools.{Edit, Find, Grep, Ls, Read, Write}

  @doc """
  Start a `PiEx.DeepAgent` supervised agent process.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start(Config.t()) :: {:ok, pid()} | {:error, String.t()}
  def start(%Config{} = config) do
    with {:ok, canonical} <- Config.validate(config) do
      root = canonical.project_root
      built_in = built_in_tools(root)
      all_tools = built_in ++ canonical.extra_tools

      system_prompt =
        canonical.system_prompt ||
          SystemPrompt.build(all_tools)

      agent_config = %PiEx.Agent.Config{
        model: canonical.model,
        system_prompt: system_prompt,
        tools: all_tools,
        api_key: canonical.api_key,
        temperature: canonical.temperature,
        max_tokens: canonical.max_tokens
      }

      PiEx.Agent.start(agent_config)
    end
  end

  @doc """
  Start a `PiEx.DeepAgent` supervised agent process, raising on error.
  """
  @spec start!(Config.t()) :: pid()
  def start!(%Config{} = config) do
    case start(config) do
      {:ok, pid} -> pid
      {:error, reason} -> raise "PiEx.DeepAgent.start!/1 failed: #{reason}"
    end
  end

  @doc "Return the list of built-in tools for the given `project_root`."
  @spec built_in_tools(String.t()) :: [PiEx.Agent.Tool.t()]
  def built_in_tools(project_root) do
    [
      Ls.tool(project_root),
      Find.tool(project_root),
      Read.tool(project_root),
      Grep.tool(project_root),
      Write.tool(project_root),
      Edit.tool(project_root)
    ]
  end
end
