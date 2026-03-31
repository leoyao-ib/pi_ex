defmodule PiEx.AI.StreamEvent do
  @moduledoc """
  The tagged-tuple event protocol emitted by AI provider streams.

  Consumers iterate the stream with `for event <- stream`, pattern-matching on each event:

      for event <- PiEx.AI.stream(model, context) do
        case event do
          {:start, partial} -> ...
          {:text_delta, _idx, delta, _partial} -> IO.write(delta)
          {:done, :stop, message} -> IO.puts("\\nDone")
          {:error, reason, message} -> IO.puts("Error: \#{inspect(reason)}")
          _ -> :ok
        end
      end

  ## Event types

  ### Lifecycle
  - `{:start, partial}` — stream opened; `partial` is the initial empty AssistantMessage

  ### Text blocks
  - `{:text_start, index, partial}` — new text block at content `index`
  - `{:text_delta, index, delta, partial}` — text fragment appended
  - `{:text_end, index, content, partial}` — text block complete; `content` is full text

  ### Thinking blocks (extended reasoning models)
  - `{:thinking_start, index, partial}`
  - `{:thinking_delta, index, delta, partial}`
  - `{:thinking_end, index, content, partial}`

  ### Tool call blocks
  - `{:toolcall_start, index, partial}`
  - `{:toolcall_delta, index, delta, partial}` — raw argument JSON fragment
  - `{:toolcall_end, index, tool_call, partial}` — `tool_call` is `%ToolCall{}`

  ### Terminal
  - `{:done, reason, message}` — stream complete; `reason` is `:stop | :length | :tool_use`
  - `{:error, reason, message}` — stream failed; `reason` is `:aborted | :error`

  `partial` is always the current `%AssistantMessage{}` with content populated so far.
  """

  alias PiEx.AI.Message.AssistantMessage
  alias PiEx.AI.Content.ToolCall

  @type stop_reason :: :stop | :length | :tool_use
  @type error_reason :: :aborted | :error

  @type t ::
          {:start, AssistantMessage.t()}
          | {:text_start, non_neg_integer(), AssistantMessage.t()}
          | {:text_delta, non_neg_integer(), String.t(), AssistantMessage.t()}
          | {:text_end, non_neg_integer(), String.t(), AssistantMessage.t()}
          | {:thinking_start, non_neg_integer(), AssistantMessage.t()}
          | {:thinking_delta, non_neg_integer(), String.t(), AssistantMessage.t()}
          | {:thinking_end, non_neg_integer(), String.t(), AssistantMessage.t()}
          | {:toolcall_start, non_neg_integer(), AssistantMessage.t()}
          | {:toolcall_delta, non_neg_integer(), String.t(), AssistantMessage.t()}
          | {:toolcall_end, non_neg_integer(), ToolCall.t(), AssistantMessage.t()}
          | {:done, stop_reason(), AssistantMessage.t()}
          | {:error, error_reason(), AssistantMessage.t()}
end
