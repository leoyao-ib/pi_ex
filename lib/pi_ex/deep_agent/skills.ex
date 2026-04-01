defmodule PiEx.DeepAgent.Skills do
  @moduledoc """
  Discovers and loads `%PiEx.DeepAgent.Skill{}` structs from a root directory.

  A skill is a subdirectory containing a `SKILL.md` file. Discovery is recursive:
  if a directory contains `SKILL.md`, it is treated as a skill root (no further
  recursion into it); otherwise its subdirectories are searched.

  Directories named `_build`, `deps`, `.git`, and `node_modules` are skipped.
  """

  require Logger

  alias PiEx.DeepAgent.Skill

  @ignored_dirs ~w[_build deps .git node_modules]

  @doc """
  Load all skills from `skills_root`.

  Returns `{:ok, [%Skill{}]}` on success, `{:error, reason}` if `skills_root`
  is not a directory. Returns `{:ok, []}` when `skills_root` is `nil`.

  On name collisions the first loaded skill wins; a warning is logged.
  """
  @spec load_all(String.t() | nil) :: {:ok, [Skill.t()]} | {:error, String.t()}
  def load_all(nil), do: {:ok, []}

  def load_all(skills_root) when is_binary(skills_root) do
    if File.dir?(skills_root) do
      skills =
        skills_root
        |> load_from_dir()
        |> deduplicate_by_name()

      {:ok, skills}
    else
      {:error, "skills_root does not exist or is not a directory: #{skills_root}"}
    end
  end

  @doc """
  Recursively scan `dir` for skills and return a list of `%Skill{}`.

  Skills are loaded in filesystem traversal order (not guaranteed to be stable
  across platforms). Name collisions are resolved by the caller via `load_all/1`.
  """
  @spec load_from_dir(String.t()) :: [Skill.t()]
  def load_from_dir(dir) when is_binary(dir) do
    skill_md = Path.join(dir, "SKILL.md")

    if File.exists?(skill_md) do
      case Skill.from_file(skill_md) do
        {:ok, skill} -> [skill]
        {:error, reason} -> Logger.warning("Skipping skill at #{dir}: #{reason}"); []
      end
    else
      dir
      |> list_subdirs()
      |> Enum.flat_map(&load_from_dir/1)
    end
  end

  # --- private ---

  defp list_subdirs(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&(&1 in @ignored_dirs))
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.filter(&File.dir?/1)
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp deduplicate_by_name(skills) do
    skills
    |> Enum.reduce({[], MapSet.new()}, fn skill, {acc, seen} ->
      if MapSet.member?(seen, skill.name) do
        Logger.warning(
          "Duplicate skill name \"#{skill.name}\" at #{skill.file_path}; skipping."
        )

        {acc, seen}
      else
        {[skill | acc], MapSet.put(seen, skill.name)}
      end
    end)
    |> then(fn {acc, _seen} -> Enum.reverse(acc) end)
  end
end
