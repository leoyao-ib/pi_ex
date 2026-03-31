defmodule PiEx.AI.MessageTest do
  use ExUnit.Case, async: true

  alias PiEx.AI.Message
  alias PiEx.AI.Message.{UserMessage, AssistantMessage, ToolResultMessage, Usage}
  alias PiEx.AI.Content.TextContent

  describe "user/1 with string" do
    test "creates a UserMessage with string content" do
      msg = Message.user("Hello!")
      assert %UserMessage{content: "Hello!"} = msg
    end

    test "timestamp is set to current time in milliseconds" do
      before_ms = System.system_time(:millisecond)
      msg = Message.user("Hi")
      after_ms = System.system_time(:millisecond)
      assert msg.timestamp >= before_ms
      assert msg.timestamp <= after_ms
    end
  end

  describe "user/1 with blocks" do
    test "creates a UserMessage with content block list" do
      blocks = [%TextContent{text: "hi"}]
      msg = Message.user(blocks)
      assert %UserMessage{content: ^blocks} = msg
    end
  end

  describe "Usage" do
    test "defaults to zero tokens" do
      assert %Usage{input_tokens: 0, output_tokens: 0} = %Usage{}
    end

    test "accepts token counts" do
      u = %Usage{input_tokens: 10, output_tokens: 5}
      assert u.input_tokens == 10
      assert u.output_tokens == 5
    end
  end

  describe "AssistantMessage" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(AssistantMessage, %{content: [], model: "gpt-4o", usage: %Usage{}})
      end
    end

    test "creates with all required fields" do
      msg = %AssistantMessage{
        content: [],
        model: "gpt-4o",
        usage: %Usage{},
        stop_reason: :stop,
        timestamp: 0
      }

      assert msg.model == "gpt-4o"
      assert msg.stop_reason == :stop
      assert msg.error_message == nil
    end
  end

  describe "ToolResultMessage" do
    test "creates with required fields" do
      msg = %ToolResultMessage{
        tool_call_id: "call_1",
        tool_name: "my_tool",
        content: [%TextContent{text: "result"}],
        is_error: false,
        timestamp: 0
      }

      assert msg.tool_call_id == "call_1"
      assert msg.is_error == false
      assert msg.details == nil
    end
  end
end
