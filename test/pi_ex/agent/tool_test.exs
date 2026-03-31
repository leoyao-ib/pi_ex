defmodule PiEx.Agent.ToolTest do
  use ExUnit.Case, async: true

  alias PiEx.Agent.Tool, as: AgentTool
  alias PiEx.AI.Tool, as: AITool
  alias PiEx.AI.Content.TextContent

  defp sample_tool do
    %AgentTool{
      name: "get_weather",
      description: "Returns current weather",
      parameters: %{"type" => "object", "properties" => %{"city" => %{"type" => "string"}}},
      label: "Get Weather",
      execute: fn _id, _params, _opts -> {:ok, %{content: [], details: nil}} end
    }
  end

  describe "to_ai_tool/1" do
    test "converts an AgentTool to an AITool" do
      ai_tool = AgentTool.to_ai_tool(sample_tool())
      assert %AITool{} = ai_tool
      assert ai_tool.name == "get_weather"
      assert ai_tool.description == "Returns current weather"
      assert ai_tool.parameters["type"] == "object"
    end

    test "preserves the JSON Schema parameters map" do
      params = %{
        "type" => "object",
        "properties" => %{
          "city" => %{"type" => "string", "description" => "City name"},
          "unit" => %{"type" => "string", "enum" => ["celsius", "fahrenheit"]}
        },
        "required" => ["city"]
      }

      tool = %AgentTool{
        name: "weather",
        description: "...",
        parameters: params,
        label: "W",
        execute: fn _, _, _ -> {:ok, %{content: [], details: nil}} end
      }

      assert AgentTool.to_ai_tool(tool).parameters == params
    end
  end

  describe "struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(AgentTool, %{name: "x", description: "y", parameters: %{}})
      end
    end

    test "execute fn is called with call_id, params, opts" do
      tool = %AgentTool{
        name: "echo",
        description: "echo",
        parameters: %{},
        label: "Echo",
        execute: fn call_id, params, _opts ->
          {:ok, %{content: [%TextContent{text: "#{call_id} #{params["msg"]}"}], details: nil}}
        end
      }

      assert {:ok, %{content: [%TextContent{text: "id1 hello"}]}} =
               tool.execute.("id1", %{"msg" => "hello"}, [])
    end
  end
end
