defmodule PiEx.Agent.ServerTest do
  # async: false — tests interact with GenServer processes and shared supervisors
  use ExUnit.Case, async: false

  alias PiEx.Agent.{Config, Server, Supervisor}
  alias PiEx.AI.Model
  alias PiEx.AI.Message
  alias PiEx.AI.Message.{AssistantMessage, Usage}
  alias PiEx.AI.Content.{TextContent, ToolCall}

  # ---------------------------------------------------------------------------
  # Fake stream helpers
  # ---------------------------------------------------------------------------

  defp text_stream(text) do
    partial_empty = %AssistantMessage{
      content: [], model: "test", usage: %Usage{}, stop_reason: :stop, timestamp: 0
    }

    partial_done = %AssistantMessage{
      content: [%TextContent{text: text}],
      model: "test",
      usage: %Usage{input_tokens: 5, output_tokens: 2},
      stop_reason: :stop,
      timestamp: 0
    }

    [
      {:start, partial_empty},
      {:text_start, 0, partial_empty},
      {:text_delta, 0, text, partial_done},
      {:text_end, 0, text, partial_done},
      {:done, :stop, partial_done}
    ]
  end

  defp tool_call_stream(call_id, tool_name, args) do
    tc = %ToolCall{id: call_id, name: tool_name, arguments: args}

    partial_empty = %AssistantMessage{
      content: [], model: "test", usage: %Usage{}, stop_reason: :tool_use, timestamp: 0
    }

    partial_done = %AssistantMessage{
      content: [tc],
      model: "test",
      usage: %Usage{},
      stop_reason: :tool_use,
      timestamp: 0
    }

    [
      {:start, partial_empty},
      {:toolcall_start, 0, partial_empty},
      {:toolcall_end, 0, tc, partial_done},
      {:done, :tool_use, partial_done}
    ]
  end

  defp base_config(stream_fn) do
    %Config{
      model: Model.new("test-model", "openai"),
      stream_fn: fn _model, _ctx, _opts -> stream_fn.() end
    }
  end

  defp start_agent!(config) do
    {:ok, pid} = Supervisor.start_agent(config)
    on_exit(fn -> DynamicSupervisor.terminate_child(PiEx.Agent.Supervisor, pid) end)
    pid
  end

  # Helper kept for future use if synchronous waiting is needed
  # defp wait_for_idle(server, timeout \ 3000) do ...

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1 and status/1" do
    test "starts in :idle status" do
      pid = start_agent!(base_config(fn -> text_stream("hi") end))
      assert Server.status(pid) == :idle
    end
  end

  describe "subscribe/2" do
    test "subscribes the calling process to events" do
      pid = start_agent!(base_config(fn -> text_stream("hi") end))
      assert :ok = Server.subscribe(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # prompt/2
  # ---------------------------------------------------------------------------

  describe "prompt/2" do
    test "returns :ok and transitions to :running" do
      pid = start_agent!(base_config(fn -> text_stream("hi") end))
      Server.subscribe(pid)
      assert :ok = Server.prompt(pid, "Hello")
    end

    test "runs to completion and becomes :idle" do
      pid = start_agent!(base_config(fn -> text_stream("result") end))
      Server.subscribe(pid)
      Server.prompt(pid, "test")
      assert_receive {:agent_event, {:agent_end, _}}, 3000
      assert Server.status(pid) == :idle
    end

    test "broadcasts agent_start and agent_end events to subscribers" do
      pid = start_agent!(base_config(fn -> text_stream("done") end))
      Server.subscribe(pid)
      Server.prompt(pid, "hello")

      assert_receive {:agent_event, :agent_start}, 3000
      assert_receive {:agent_event, {:agent_end, _}}, 3000
    end

    test "stores messages in transcript after run" do
      pid = start_agent!(base_config(fn -> text_stream("assistant response") end))
      Server.subscribe(pid)
      Server.prompt(pid, "user prompt")
      assert_receive {:agent_event, {:agent_end, _}}, 3000

      messages = Server.get_messages(pid)
      assert length(messages) >= 2

      user_msg = hd(messages)
      assert %Message.UserMessage{content: "user prompt"} = user_msg
    end

    test "returns :error when already running" do
      # Use a stream that blocks until signalled
      test_pid = self()

      pid =
        start_agent!(%Config{
          model: Model.new("test-model", "openai"),
          stream_fn: fn _m, _c, _o ->
            # Signal ready then block
            send(test_pid, :stream_started)
            receive do: (:continue -> [])
          end
        })

      Server.subscribe(pid)
      Server.prompt(pid, "first")
      assert_receive :stream_started, 1000

      assert {:error, :already_running} = Server.prompt(pid, "second")

      # Unblock and let it finish
      # Find the task pid and send :continue — just let it timeout naturally
      # or terminate agent
      DynamicSupervisor.terminate_child(PiEx.Agent.Supervisor, pid)
    end
  end

  # ---------------------------------------------------------------------------
  # steer/2
  # ---------------------------------------------------------------------------

  describe "steer/2" do
    test "queued steering messages are included in subsequent run turn" do
      received_messages = :ets.new(:steering_msgs, [:set, :public])
      test_pid = self()
      count = :counters.new(1, [])

      pid =
        start_agent!(%Config{
          model: Model.new("test-model", "openai"),
          stream_fn: fn _m, ctx, _o ->
            :counters.add(count, 1, 1)
            :ets.insert(received_messages, {:messages, ctx.messages})
            send(test_pid, {:turn, :counters.get(count, 1)})
            text_stream("ok")
          end
        })

      Server.subscribe(pid)
      Server.steer(pid, Message.user("steered"))
      Server.prompt(pid, "initial")

      assert_receive {:agent_event, {:agent_end, _}}, 3000
      [{:messages, msgs}] = :ets.lookup(received_messages, :messages)
      contents = Enum.map(msgs, fn m -> m.content end)
      assert "steered" in contents
    end
  end

  # ---------------------------------------------------------------------------
  # abort/1
  # ---------------------------------------------------------------------------

  describe "abort/1" do
    test "abort on an idle agent is a no-op" do
      pid = start_agent!(base_config(fn -> text_stream("hi") end))
      assert :ok = Server.abort(pid)
      assert Server.status(pid) == :idle
    end

    test "abort stops a running agent" do
      test_pid = self()

      pid =
        start_agent!(%Config{
          model: Model.new("test-model", "openai"),
          stream_fn: fn _m, _c, _o ->
            send(test_pid, :loop_started)
            receive do: (:never -> [])
          end
        })

      Server.subscribe(pid)
      Server.prompt(pid, "go")
      assert_receive :loop_started, 1000

      Server.abort(pid)
      Process.sleep(100)
      assert Server.status(pid) == :idle
    end
  end

  # ---------------------------------------------------------------------------
  # Tool execution via loop
  # ---------------------------------------------------------------------------

  describe "tool execution" do
    test "tool is called and result is added to messages" do
      executed = :ets.new(:executed, [:set, :public])
      call_count = :counters.new(1, [])

      echo_tool = %PiEx.Agent.Tool{
        name: "echo",
        description: "echoes input",
        parameters: %{},
        label: "Echo",
        execute: fn call_id, params, _opts ->
          :ets.insert(executed, {:call, call_id, params})
          {:ok, %{content: [%TextContent{text: "echoed"}], details: nil}}
        end
      }

      # First call returns a tool_use, second call (after tool result) returns text
      pid =
        start_agent!(%Config{
          model: Model.new("test-model", "openai"),
          tools: [echo_tool],
          stream_fn: fn _m, _ctx, _o ->
            :counters.add(call_count, 1, 1)
            turn = :counters.get(call_count, 1)

            if turn == 1 do
              tool_call_stream("call_1", "echo", %{"msg" => "hello"})
            else
              text_stream("done")
            end
          end
        })

      Server.subscribe(pid)
      Server.prompt(pid, "use echo tool")
      assert_receive {:agent_event, {:agent_end, _}}, 5000

      assert :ets.member(executed, :call)
    end

    test "tool_execution_start and tool_execution_end events are broadcast" do
      echo_tool = %PiEx.Agent.Tool{
        name: "echo",
        description: "echo",
        parameters: %{},
        label: "Echo",
        execute: fn _id, _params, _opts ->
          {:ok, %{content: [%TextContent{text: "ok"}], details: nil}}
        end
      }

      call_count = :counters.new(1, [])

      pid =
        start_agent!(%Config{
          model: Model.new("test-model", "openai"),
          tools: [echo_tool],
          stream_fn: fn _m, _ctx, _o ->
            :counters.add(call_count, 1, 1)

            if :counters.get(call_count, 1) == 1 do
              tool_call_stream("call_1", "echo", %{})
            else
              text_stream("done")
            end
          end
        })

      Server.subscribe(pid)
      Server.prompt(pid, "go")
      assert_receive {:agent_event, {:agent_end, _}}, 5000

      assert_received {:agent_event, {:tool_execution_start, "call_1", "echo", _}}
      assert_received {:agent_event, {:tool_execution_end, "call_1", "echo", _, false}}
    end
  end

  # ---------------------------------------------------------------------------
  # get_messages/1
  # ---------------------------------------------------------------------------

  describe "get_messages/1" do
    test "returns empty list before any prompts" do
      pid = start_agent!(base_config(fn -> text_stream("hi") end))
      assert Server.get_messages(pid) == []
    end

    test "returns full transcript including user and assistant messages" do
      pid = start_agent!(base_config(fn -> text_stream("pong") end))
      Server.subscribe(pid)
      Server.prompt(pid, "ping")
      assert_receive {:agent_event, {:agent_end, _}}, 3000

      messages = Server.get_messages(pid)
      roles = Enum.map(messages, fn m -> m.__struct__ end)
      assert Message.UserMessage in roles
      assert AssistantMessage in roles
    end
  end
end
