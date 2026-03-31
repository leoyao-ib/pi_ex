defmodule PiEx.Agent.Tool do
  @moduledoc """
  An agent-level tool definition, extending `PiEx.AI.Tool` with execution logic.

  ## Fields
  - `:name` — tool name (must match what the model will call)
  - `:description` — human-readable description passed to the model
  - `:parameters` — JSON Schema map for the tool's arguments
  - `:label` — short human-readable label for UI/logging
  - `:execute` — `(call_id, params, opts) -> {:ok, result} | {:error, reason}`
    where `result` is `%{content: [TextContent | ImageContent], details: term()}`

  ## Example

      %PiEx.Agent.Tool{
        name: "get_weather",
        description: "Returns current weather for a city",
        parameters: %{
          "type" => "object",
          "properties" => %{
            "city" => %{"type" => "string", "description" => "The city name"}
          },
          "required" => ["city"]
        },
        label: "Get Weather",
        execute: fn _call_id, %{"city" => city}, _opts ->
          {:ok, %{content: [%PiEx.AI.Content.TextContent{text: "Sunny, 22°C in \#{city}"}], details: nil}}
        end
      }
  """

  alias PiEx.AI.Content.{TextContent, ImageContent}

  @enforce_keys [:name, :description, :parameters, :label, :execute]
  defstruct [:name, :description, :parameters, :label, :execute]

  @type result :: %{content: [TextContent.t() | ImageContent.t()], details: term()}

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          parameters: map(),
          label: String.t(),
          execute: (String.t(), map(), keyword() -> {:ok, result()} | {:error, String.t()})
        }

  @doc "Convert an AgentTool to a plain `PiEx.AI.Tool` for passing to the LLM context."
  @spec to_ai_tool(t()) :: PiEx.AI.Tool.t()
  def to_ai_tool(%__MODULE__{name: name, description: desc, parameters: params}) do
    %PiEx.AI.Tool{name: name, description: desc, parameters: params}
  end
end
