defmodule PiEx.AI.Tool do
  @moduledoc """
  Tool definition passed to the LLM.

  `parameters` is a plain JSON Schema map (e.g. `%{"type" => "object", "properties" => ...}`).
  It is forwarded as-is in the OpenAI request body—no runtime validation is performed.
  """
  @enforce_keys [:name, :description, :parameters]
  defstruct [:name, :description, :parameters]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          parameters: map()
        }
end

defmodule PiEx.AI.Context do
  @moduledoc "The full conversation context sent to a provider."
  @enforce_keys [:messages]
  defstruct [:system_prompt, :messages, tools: []]

  @type t :: %__MODULE__{
          system_prompt: String.t() | nil,
          messages: [PiEx.AI.Message.t()],
          tools: [PiEx.AI.Tool.t()]
        }
end
