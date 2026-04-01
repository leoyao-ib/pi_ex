defmodule PiEx.DeepAgent.Skill do
  @moduledoc """
  Represents a skill: a self-contained capability package stored as a directory
  containing a `SKILL.md` file with YAML frontmatter.

  ## Frontmatter fields

  - `name` (required) — lowercase alphanumeric + hyphens, max 64 chars
  - `description` (required) — max 1024 chars
  - `disable-model-invocation` (optional, default `false`) — when `true`,
    the skill is not listed in the system prompt and can only be invoked manually
  """

  @enforce_keys [:name, :description, :file_path, :base_dir]
  defstruct [
    :name,
    :description,
    :file_path,
    :base_dir,
    disable_model_invocation: false
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          file_path: String.t(),
          base_dir: String.t(),
          disable_model_invocation: boolean()
        }

  @doc """
  Load a `%Skill{}` from the absolute path to a `SKILL.md` file.

  Returns `{:ok, skill}` or `{:error, reason}`.
  """
  @spec from_file(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_file(file_path) when is_binary(file_path) do
    with {:ok, content} <- read_file(file_path),
         {:ok, frontmatter} <- parse_frontmatter(content, file_path) do
      skill = %__MODULE__{
        name: frontmatter["name"],
        description: frontmatter["description"],
        file_path: file_path,
        base_dir: Path.dirname(file_path),
        disable_model_invocation: Map.get(frontmatter, "disable-model-invocation", false)
      }

      {:ok, skill}
    end
  end

  # --- private ---

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, "SKILL.md not found: #{path}"}
      {:error, reason} -> {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  defp parse_frontmatter(content, file_path) do
    case String.split(content, "---", parts: 3) do
      ["", raw_fm, _body] ->
        fm = parse_kv(raw_fm)
        validate_frontmatter(fm, file_path)

      _ ->
        {:error, "Missing YAML frontmatter in #{file_path}"}
    end
  end

  defp parse_kv(raw) do
    raw
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          parsed_value =
            value
            |> String.trim()
            |> parse_value()

          Map.put(acc, String.trim(key), parsed_value)

        _ ->
          acc
      end
    end)
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(s), do: s

  defp validate_frontmatter(fm, file_path) do
    with {:name, name} when is_binary(name) and name != "" <- {:name, Map.get(fm, "name")},
         {:desc, desc} when is_binary(desc) and desc != "" <-
           {:desc, Map.get(fm, "description")} do
      {:ok, fm}
    else
      {:name, _} -> {:error, "Missing or empty `name` in frontmatter of #{file_path}"}
      {:desc, _} -> {:error, "Missing or empty `description` in frontmatter of #{file_path}"}
    end
  end
end
