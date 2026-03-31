defmodule PiEx.AI.Model do
  @moduledoc "Identifies an LLM model from a specific provider."
  @enforce_keys [:id, :provider]
  defstruct [:id, :provider]

  @type t :: %__MODULE__{
          id: String.t(),
          provider: String.t()
        }

  @doc "Construct a Model."
  @spec new(String.t(), String.t()) :: t()
  def new(id, provider), do: %__MODULE__{id: id, provider: provider}
end
