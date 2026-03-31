# PiEx

An Elixir port of [pi-mono](https://github.com/badlogic/pi-mono)'s `ai` and `agent` packages. Provides streaming LLM completions (OpenAI) and a stateful, tool-calling agent built on OTP.

## Packages

- **`PiEx.AI`** — Streaming and synchronous LLM completions. Currently supports OpenAI.
- **`PiEx.Agent`** — Stateful GenServer-backed agent with tool execution, steering, and event subscriptions.

## Requirements

- Elixir ~> 1.19 / OTP 27
- [`req`](https://hex.pm/packages/req) ~> 0.5
- [`jason`](https://hex.pm/packages/jason) ~> 1.4

## Setup

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:req, "~> 0.5"},
    {:jason, "~> 1.4"}
  ]
end
```

Set your OpenAI API key:

```bash
export OPENAI_API_KEY="sk-..."
```

## PiEx.AI — LLM streaming

```elixir
model = PiEx.AI.Model.new("gpt-4o", "openai")
context = %PiEx.AI.Context{messages: [PiEx.AI.Message.user("Hello!")]}

# Streaming
for event <- PiEx.AI.stream(model, context) do
  case event do
    {:text_delta, _idx, delta, _partial} -> IO.write(delta)
    {:done, _reason, _msg} -> IO.puts("")
    _ -> :ok
  end
end

# Synchronous
{:ok, message} = PiEx.AI.complete(model, context)
```

### Stream events

| Event | Description |
|---|---|
| `{:start, partial}` | Stream opened; initial empty message |
| `{:text_start, idx, partial}` | Text block started |
| `{:text_delta, idx, delta, partial}` | Text chunk received |
| `{:text_end, idx, text, partial}` | Text block finished |
| `{:thinking_start/delta/end, ...}` | Thinking block (extended thinking models) |
| `{:toolcall_start, idx, partial}` | Tool call started |
| `{:toolcall_delta, idx, delta, partial}` | Tool call argument chunk |
| `{:toolcall_end, idx, call, partial}` | Tool call complete |
| `{:done, reason, message}` | Stream finished; `reason` is `:stop`, `:tool_use`, or `:length` |
| `{:error, reason, message}` | Stream error; `reason` is `:error` or `:aborted` |

## PiEx.Agent — Stateful agent

```elixir
config = %PiEx.Agent.Config{
  model: PiEx.AI.Model.new("gpt-4o", "openai"),
  system_prompt: "You are a helpful assistant."
}

{:ok, agent} = PiEx.Agent.start(config)
PiEx.Agent.subscribe(agent)
:ok = PiEx.Agent.prompt(agent, "What is 2 + 2?")

receive do
  {:agent_event, {:agent_end, _messages}} -> IO.puts("done")
  {:agent_event, {:message_update, _msg, {:text_delta, _, delta, _}}} -> IO.write(delta)
end
```

### With tools

```elixir
weather_tool = %PiEx.Agent.Tool{
  name: "get_weather",
  description: "Get current weather for a city",
  parameters: %{
    "type" => "object",
    "properties" => %{"city" => %{"type" => "string"}},
    "required" => ["city"]
  },
  label: "Get Weather",
  execute: fn _id, %{"city" => city}, _opts ->
    {:ok, %{content: [%PiEx.AI.Content.TextContent{text: "Sunny in #{city}"}], details: nil}}
  end
}

config = %PiEx.Agent.Config{model: model, tools: [weather_tool]}
{:ok, agent} = PiEx.Agent.start(config)
```

### Agent API

| Function | Description |
|---|---|
| `PiEx.Agent.start/1` | Start a supervised agent. Returns `{:ok, pid}` |
| `PiEx.Agent.subscribe/2` | Subscribe to `{:agent_event, event}` messages |
| `PiEx.Agent.prompt/2` | Start a run with a text prompt or message list |
| `PiEx.Agent.steer/2` | Inject messages for the next turn mid-run |
| `PiEx.Agent.follow_up/2` | Inject messages to restart the agent after it stops |
| `PiEx.Agent.abort/1` | Abort the current run |
| `PiEx.Agent.get_messages/1` | Return the full conversation transcript |
| `PiEx.Agent.status/1` | Return `:idle` or `:running` |
| `PiEx.Agent.stop/1` | Shut down the agent process |

### Agent config

```elixir
%PiEx.Agent.Config{
  model: model,                    # required
  system_prompt: "...",
  tools: [tool1, tool2],
  api_key: "sk-...",               # overrides OPENAI_API_KEY env var
  temperature: 0.7,
  max_tokens: 4096,

  # Hooks (all optional)
  before_tool_call: fn id, name, args -> :ok end,
  after_tool_call: fn id, name, result -> result end,
  get_steering_messages: fn -> [] end,
  get_follow_up_messages: fn -> [] end,
  transform_context: fn ctx -> ctx end,
  convert_to_llm: fn messages -> messages end
}
```

### Agent events

| Event | Description |
|---|---|
| `:agent_start` | Run started |
| `{:agent_end, messages}` | Run complete; full transcript |
| `:turn_start` | LLM turn started |
| `{:turn_end, assistant_msg, tool_results}` | LLM turn complete |
| `{:message_start, msg}` | Message streaming started |
| `{:message_update, msg, stream_event}` | Message streaming update |
| `{:message_end, msg}` | Message streaming complete |
| `{:tool_execution_start, id, name, args}` | Tool call started |
| `{:tool_execution_update, id, name, args, partial}` | Tool call progress |
| `{:tool_execution_end, id, name, result, is_error}` | Tool call complete |

