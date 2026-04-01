defmodule PiEx.AI.ProviderConfig do
  @moduledoc """
  Resolves provider configuration (API keys and base URLs) from multiple sources.

  Resolution order (highest to lowest priority):
  1. Environment variables (e.g. `OPENAI_API_KEY`)
  2. Elixir application config (`config :pi_ex, :openai, api_key: "..."`)

  Call-time opts take priority over both and are handled by each provider directly.

  ## Example configuration

      # config/dev.exs
      config :pi_ex, :openai,
        api_key: "sk-...",
        base_url: "https://api.openai.com/v1"

      config :pi_ex, :litellm,
        api_key: "sk-...",
        base_url: "http://localhost:4000/v1"
  """

  @provider_env_vars %{
    "openai" => %{api_key: "OPENAI_API_KEY", base_url: nil},
    "openai_responses" => %{api_key: "OPENAI_API_KEY", base_url: nil},
    "litellm" => %{api_key: "LITELLM_API_KEY", base_url: "LITELLM_API_BASE"}
  }

  @doc "Returns the API key for the given provider, or `nil`."
  @spec get_api_key(String.t()) :: String.t() | nil
  def get_api_key(provider) do
    env_get(provider, :api_key) || app_config_get(provider, :api_key)
  end

  @doc "Returns the base URL for the given provider, or `nil`."
  @spec get_base_url(String.t()) :: String.t() | nil
  def get_base_url(provider) do
    env_get(provider, :base_url) || app_config_get(provider, :base_url)
  end

  defp env_get(provider, key) do
    case get_in(@provider_env_vars, [provider, key]) do
      nil -> nil
      env_var -> System.get_env(env_var)
    end
  end

  defp app_config_get(provider, key) do
    provider
    |> String.to_existing_atom()
    |> then(&Application.get_env(:pi_ex, &1, []))
    |> Keyword.get(key)
  rescue
    ArgumentError -> nil
  end
end
