defmodule PiEx.AI.ContentTest do
  use ExUnit.Case, async: true

  alias PiEx.AI.Content.{TextContent, ThinkingContent, ImageContent, ToolCall}

  describe "TextContent" do
    test "creates with text" do
      assert %TextContent{text: "hello"} = %TextContent{text: "hello"}
    end

    test "enforces :text key" do
      assert_raise ArgumentError, fn -> struct!(TextContent, %{}) end
    end
  end

  describe "ThinkingContent" do
    test "creates with thinking text" do
      assert %ThinkingContent{thinking: "reasoning..."} = %ThinkingContent{thinking: "reasoning..."}
    end

    test "defaults redacted to false" do
      assert %ThinkingContent{redacted: false} = %ThinkingContent{thinking: "x"}
    end

    test "can be marked as redacted" do
      block = %ThinkingContent{thinking: "x", redacted: true}
      assert block.redacted == true
    end

    test "enforces :thinking key" do
      assert_raise ArgumentError, fn -> struct!(ThinkingContent, %{}) end
    end
  end

  describe "ImageContent" do
    test "creates with data and mime_type" do
      block = %ImageContent{data: "base64abc", mime_type: "image/png"}
      assert block.data == "base64abc"
      assert block.mime_type == "image/png"
    end

    test "enforces :data and :mime_type keys" do
      assert_raise ArgumentError, fn -> struct!(ImageContent, %{data: "abc"}) end
      assert_raise ArgumentError, fn -> struct!(ImageContent, %{mime_type: "image/png"}) end
    end
  end

  describe "ToolCall" do
    test "creates with required fields" do
      tc = %ToolCall{id: "call_1", name: "get_weather", arguments: %{"city" => "London"}}
      assert tc.id == "call_1"
      assert tc.name == "get_weather"
      assert tc.arguments == %{"city" => "London"}
    end

    test "enforces required keys" do
      assert_raise ArgumentError, fn -> struct!(ToolCall, %{id: "x", name: "y"}) end
    end
  end
end
