defmodule PiEx.AI.ProviderConfigTest do
  # async: false — Application.put_env and System.put_env mutate global state
  use ExUnit.Case, async: false

  alias PiEx.AI.ProviderConfig

  setup do
    on_exit(fn ->
      Application.delete_env(:pi_ex, :openai)
      Application.delete_env(:pi_ex, :litellm)
      System.delete_env("OPENAI_API_KEY")
      System.delete_env("LITELLM_API_KEY")
      System.delete_env("LITELLM_API_BASE")
    end)

    :ok
  end

  describe "get_api_key/1" do
    test "returns nil when no config or env var set" do
      assert ProviderConfig.get_api_key("openai") == nil
    end

    test "returns value from env var" do
      System.put_env("OPENAI_API_KEY", "sk-from-env")
      assert ProviderConfig.get_api_key("openai") == "sk-from-env"
    end

    test "returns value from app config" do
      Application.put_env(:pi_ex, :openai, api_key: "sk-from-config")
      assert ProviderConfig.get_api_key("openai") == "sk-from-config"
    end

    test "env var takes priority over app config" do
      Application.put_env(:pi_ex, :openai, api_key: "sk-from-config")
      System.put_env("OPENAI_API_KEY", "sk-from-env")
      assert ProviderConfig.get_api_key("openai") == "sk-from-env"
    end

    test "works for litellm provider" do
      System.put_env("LITELLM_API_KEY", "sk-litellm-env")
      assert ProviderConfig.get_api_key("litellm") == "sk-litellm-env"
    end

    test "returns nil for unknown provider" do
      assert ProviderConfig.get_api_key("unknown_provider") == nil
    end
  end

  describe "get_base_url/1" do
    test "returns nil when no config or env var set" do
      # openai has no base_url env var defined
      assert ProviderConfig.get_base_url("openai") == nil
    end

    test "returns base_url from app config for openai" do
      Application.put_env(:pi_ex, :openai, base_url: "https://my-proxy.example.com/v1")
      assert ProviderConfig.get_base_url("openai") == "https://my-proxy.example.com/v1"
    end

    test "returns base_url from LITELLM_API_BASE env var" do
      System.put_env("LITELLM_API_BASE", "http://my-litellm/v1")
      assert ProviderConfig.get_base_url("litellm") == "http://my-litellm/v1"
    end

    test "env var takes priority over app config for litellm base_url" do
      Application.put_env(:pi_ex, :litellm, base_url: "http://config-litellm/v1")
      System.put_env("LITELLM_API_BASE", "http://env-litellm/v1")
      assert ProviderConfig.get_base_url("litellm") == "http://env-litellm/v1"
    end

    test "returns nil for unknown provider" do
      assert ProviderConfig.get_base_url("unknown_provider") == nil
    end
  end
end
