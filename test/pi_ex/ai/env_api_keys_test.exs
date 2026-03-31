defmodule PiEx.AI.EnvApiKeysTest do
  # async: false because we mutate the process environment
  use ExUnit.Case, async: false

  alias PiEx.AI.EnvApiKeys

  describe "get/1 - openai" do
    test "returns the key when OPENAI_API_KEY is set" do
      System.put_env("OPENAI_API_KEY", "sk-test123")

      on_exit(fn -> System.delete_env("OPENAI_API_KEY") end)

      assert EnvApiKeys.get("openai") == "sk-test123"
    end

    test "returns nil when OPENAI_API_KEY is not set" do
      System.delete_env("OPENAI_API_KEY")
      assert EnvApiKeys.get("openai") == nil
    end
  end

  describe "get/1 - unknown provider" do
    test "returns nil for an unknown provider" do
      assert EnvApiKeys.get("unknown-provider") == nil
    end
  end

  describe "env_var_name/1" do
    test "returns OPENAI_API_KEY for openai" do
      assert EnvApiKeys.env_var_name("openai") == "OPENAI_API_KEY"
    end

    test "returns nil for unknown providers" do
      assert EnvApiKeys.env_var_name("bedrock") == nil
    end
  end
end
