defmodule PiEx.DeepAgent.Tools.EditDiff do
  @moduledoc """
  Utility module for applying edits and generating diffs. Not an LLM tool.
  """

  @doc """
  Find the start/end lines of `old_text` within `content`.

  Tries exact match first, then normalized match (strips trailing whitespace,
  normalizes unicode smart quotes/dashes).

  Returns `{:ok, %{start_line: n, end_line: n}}` (1-indexed) or `{:error, reason}`.
  """
  @spec fuzzy_find_text(String.t(), String.t()) ::
          {:ok, %{start_line: pos_integer(), end_line: pos_integer()}} | {:error, String.t()}
  def fuzzy_find_text(content, old_text) do
    content_lines = String.split(content, "\n")
    old_lines = String.split(old_text, "\n")

    case find_lines(content_lines, old_lines, &(&1)) do
      {:ok, start_line, end_line} ->
        {:ok, %{start_line: start_line, end_line: end_line}}

      :not_found ->
        case find_lines(content_lines, old_lines, &normalize/1) do
          {:ok, start_line, end_line} ->
            {:ok, %{start_line: start_line, end_line: end_line}}

          :not_found ->
            {:error, "text not found in content"}
        end
    end
  end

  @doc """
  Apply a list of edits to `content`. All edits are matched against the ORIGINAL content,
  not applied sequentially.

  Returns `{:ok, new_content}` or `{:error, reason}`.
  """
  @spec apply_edits(String.t(), [%{old_text: String.t(), new_text: String.t()}]) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_edits(content, edits) do
    with {:ok, located} <- locate_all_edits(content, edits) do
      sorted = Enum.sort_by(located, fn {%{start_line: s}, _} -> s end, :desc)
      lines = String.split(content, "\n")

      result =
        Enum.reduce(sorted, lines, fn {range, new_text}, acc ->
          new_lines = String.split(new_text, "\n")
          replace_lines(acc, range.start_line, range.end_line, new_lines)
        end)

      {:ok, Enum.join(result, "\n")}
    end
  end

  @doc """
  Generate a unified diff between old and new content for the given path.

  Writes temp files to `System.tmp_dir!/0`, runs `diff -u`, cleans up, and returns
  the diff string.
  """
  @spec generate_diff(String.t(), String.t(), String.t()) :: String.t()
  def generate_diff(old_content, new_content, path) do
    tmp = System.tmp_dir!()
    base = Path.basename(path)
    old_path = Path.join(tmp, "#{base}.old.#{:erlang.unique_integer([:positive])}")
    new_path = Path.join(tmp, "#{base}.new.#{:erlang.unique_integer([:positive])}")

    try do
      File.write!(old_path, old_content)
      File.write!(new_path, new_content)

      {diff, _exit_code} = System.cmd("diff", ["-u", old_path, new_path], stderr_to_stdout: true)

      diff
    after
      File.rm(old_path)
      File.rm(new_path)
    end
  end

  # --- Private helpers ---

  defp find_lines(content_lines, old_lines, transform) do
    transformed_content = Enum.map(content_lines, transform)
    transformed_old = Enum.map(old_lines, transform)
    n = length(old_lines)
    total = length(content_lines)

    result =
      Enum.find(0..(total - n), fn i ->
        Enum.slice(transformed_content, i, n) == transformed_old
      end)

    case result do
      nil -> :not_found
      i -> {:ok, i + 1, i + n}
    end
  end

  defp normalize(line) do
    line
    |> String.trim_trailing()
    |> String.replace("\u2018", "'")
    |> String.replace("\u2019", "'")
    |> String.replace("\u201C", "\"")
    |> String.replace("\u201D", "\"")
    |> String.replace("\u2013", "-")
    |> String.replace("\u2014", "--")
  end

  defp locate_all_edits(content, edits) do
    Enum.reduce_while(edits, {:ok, []}, fn edit, {:ok, acc} ->
      case fuzzy_find_text(content, edit.old_text) do
        {:ok, range} -> {:cont, {:ok, [{range, edit.new_text} | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp replace_lines(lines, start_line, end_line, new_lines) do
    before = Enum.take(lines, start_line - 1)
    after_part = Enum.drop(lines, end_line)
    before ++ new_lines ++ after_part
  end
end
