defmodule PiEx.AI.ToolTest do
  use ExUnit.Case, async: true

  alias PiEx.AI.Tool
  alias PiEx.AI.Context
  alias PiEx.AI.Message

  describe "Tool struct" do
    test "creates with required fields" do
      tool = %Tool{
        name: "get_weather",
        description: "Returns current weather",
        parameters: %{"type" => "object", "properties" => %{}}
      }

      assert tool.name == "get_weather"
      assert tool.parameters["type"] == "object"
    end

    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Tool, %{name: "x", description: "y"})
      end
    end
  end

  describe "Context struct" do
    test "creates with messages only" do
      ctx = %Context{messages: []}
      assert ctx.messages == []
      assert ctx.system_prompt == nil
      assert ctx.tools == []
    end

    test "creates with all fields" do
      msg = Message.user("hi")

      ctx = %Context{
        system_prompt: "You are helpful.",
        messages: [msg],
        tools: []
      }

      assert ctx.system_prompt == "You are helpful."
      assert length(ctx.messages) == 1
    end

    test "enforces :messages key" do
      assert_raise ArgumentError, fn -> struct!(Context, %{}) end
    end
  end
end
