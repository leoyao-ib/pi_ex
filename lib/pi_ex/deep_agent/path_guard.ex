defmodule PiEx.DeepAgent.PathGuard do
  @moduledoc """
  Security utility that ensures user-supplied paths stay within a canonical project root.

  `canonical_root` must be a pre-resolved absolute path (via `File.real_path!/1`).
  Does NOT follow symlinks in `user_path`.
  """

  @doc """
  Resolve `user_path` relative to `canonical_root` and assert containment.

  Returns `{:ok, abs_path}` or `{:error, "path is outside project root"}`.
  """
  @spec resolve(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve(canonical_root, user_path) do
    abs_path = Path.expand(user_path, canonical_root)

    if abs_path == canonical_root or String.starts_with?(abs_path, canonical_root <> "/") do
      {:ok, abs_path}
    else
      {:error, "path is outside project root"}
    end
  end
end
