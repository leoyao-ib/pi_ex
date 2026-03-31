defmodule PiEx.AI.ModelTest do
  use ExUnit.Case, async: true

  alias PiEx.AI.Model

  describe "new/2" do
    test "creates a model struct" do
      model = Model.new("gpt-4o", "openai")
      assert model.id == "gpt-4o"
      assert model.provider == "openai"
    end

    test "stores arbitrary provider names" do
      model = Model.new("claude-3-5-sonnet-20241022", "anthropic")
      assert model.provider == "anthropic"
    end
  end

  describe "struct" do
    test "enforces :id and :provider keys" do
      assert_raise ArgumentError, fn -> struct!(Model, %{id: "gpt-4o"}) end
      assert_raise ArgumentError, fn -> struct!(Model, %{provider: "openai"}) end
    end
  end
end
