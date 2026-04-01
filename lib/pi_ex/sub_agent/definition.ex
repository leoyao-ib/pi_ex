defmodule PiEx.SubAgent.Definition do
  @moduledoc """
  Configuration for a named, pre-defined subagent.

  Pre-defined subagents can be registered globally in `PiEx.SubAgent.Registry`
  or provided inline via `PiEx.Agent.Config.subagents`. When invoked via the
  `run_agent` tool, any `nil` field is inherited from the calling agent's config
  (model, tools, system_prompt).

  ## Fields

  - `:name` — unique identifier (required); referenced in `run_agent(agent: "name")`
  - `:description` — shown to the main agent so it knows when to use this subagent
  - `:model` — `nil` = inherit from calling agent
  - `:tools` — `nil` = inherit from calling agent; `run_agent` is always re-injected per-agent
  - `:extra_tools` — appended to the resolved tool list regardless of inheritance
  - `:system_prompt` — `nil` = inherit from calling agent
  - `:max_depth` — override max nesting depth; `nil` = inherit from calling agent
  """

  @enforce_keys [:name, :description]
  defstruct [
    :name,
    :description,
    :model,
    :tools,
    :extra_tools,
    :system_prompt,
    :max_depth
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          model: PiEx.AI.Model.t() | nil,
          tools: [PiEx.Agent.Tool.t()] | nil,
          extra_tools: [PiEx.Agent.Tool.t()] | nil,
          system_prompt: String.t() | nil,
          max_depth: non_neg_integer() | nil
        }
end
