defmodule PiEx.AI.Content do
  @moduledoc """
  Content block types that appear inside messages.
  """

  defmodule TextContent do
    @moduledoc "A plain text content block."
    @enforce_keys [:text]
    defstruct [:text]

    @type t :: %__MODULE__{text: String.t()}
  end

  defmodule ThinkingContent do
    @moduledoc "A model thinking/reasoning content block."
    @enforce_keys [:thinking]
    defstruct [:thinking, redacted: false]

    @type t :: %__MODULE__{thinking: String.t(), redacted: boolean()}
  end

  defmodule ImageContent do
    @moduledoc "A base64-encoded image content block."
    @enforce_keys [:data, :mime_type]
    defstruct [:data, :mime_type]

    @type t :: %__MODULE__{data: String.t(), mime_type: String.t()}
  end

  defmodule ToolCall do
    @moduledoc "A tool call issued by the model."
    @enforce_keys [:id, :name, :arguments]
    defstruct [:id, :name, :arguments]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            arguments: map()
          }
  end

  @type block :: TextContent.t() | ThinkingContent.t() | ImageContent.t() | ToolCall.t()
  @type user_block :: TextContent.t() | ImageContent.t()
  @type assistant_block :: TextContent.t() | ThinkingContent.t() | ToolCall.t()
  @type tool_result_block :: TextContent.t() | ImageContent.t()
end
