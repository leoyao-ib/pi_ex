defmodule PiEx.DeepAgent.Tools.Truncate do
  @moduledoc """
  Utility module for truncating content. Not an LLM tool.
  """

  @default_max_lines 2000
  @default_max_bytes 51_200
  @grep_max_line_length 500

  @doc "Truncate content from the start, keeping the beginning."
  @spec truncate_head(String.t(), keyword()) ::
          {String.t(), %{truncated: boolean(), lines_removed: non_neg_integer()}}
  def truncate_head(content, opts \\ []) do
    max_lines = Keyword.get(opts, :max_lines, @default_max_lines)
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)

    lines = String.split(content, "\n", trim: false)
    total_lines = length(lines)

    {kept_lines, lines_removed} =
      lines
      |> Enum.take(max_lines)
      |> enforce_byte_limit(max_bytes, total_lines)

    truncated = lines_removed > 0
    {Enum.join(kept_lines, "\n"), %{truncated: truncated, lines_removed: lines_removed}}
  end

  @doc "Truncate content from the end, keeping the tail."
  @spec truncate_tail(String.t(), keyword()) ::
          {String.t(), %{truncated: boolean(), lines_removed: non_neg_integer()}}
  def truncate_tail(content, opts \\ []) do
    max_lines = Keyword.get(opts, :max_lines, @default_max_lines)
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)

    lines = String.split(content, "\n", trim: false)
    total_lines = length(lines)

    kept_lines = Enum.take(lines, -max_lines)
    lines_removed_by_count = total_lines - length(kept_lines)

    {final_lines, lines_removed_by_bytes} =
      enforce_byte_limit_tail(kept_lines, max_bytes)

    lines_removed = lines_removed_by_count + lines_removed_by_bytes
    truncated = lines_removed > 0
    {Enum.join(final_lines, "\n"), %{truncated: truncated, lines_removed: lines_removed}}
  end

  @doc "Truncate a single line to at most max_chars characters."
  @spec truncate_line(String.t(), non_neg_integer()) :: String.t()
  def truncate_line(line, max_chars \\ @grep_max_line_length) do
    if String.length(line) > max_chars do
      String.slice(line, 0, max_chars) <> "..."
    else
      line
    end
  end

  @doc "Default max lines constant."
  def default_max_lines, do: @default_max_lines

  @doc "Default max bytes constant."
  def default_max_bytes, do: @default_max_bytes

  @doc "Grep max line length constant."
  def grep_max_line_length, do: @grep_max_line_length

  defp enforce_byte_limit(lines, max_bytes, total_lines) do
    {kept, byte_count} =
      Enum.reduce_while(lines, {[], 0}, fn line, {acc, bytes} ->
        new_bytes = bytes + byte_size(line) + 1

        if new_bytes > max_bytes do
          {:halt, {acc, bytes}}
        else
          {:cont, {[line | acc], new_bytes}}
        end
      end)

    kept_reversed = Enum.reverse(kept)
    lines_removed = total_lines - length(kept_reversed)
    _ = byte_count
    {kept_reversed, lines_removed}
  end

  defp enforce_byte_limit_tail(lines, max_bytes) do
    total = length(lines)

    {kept, _bytes} =
      lines
      |> Enum.reverse()
      |> Enum.reduce_while({[], 0}, fn line, {acc, bytes} ->
        new_bytes = bytes + byte_size(line) + 1

        if new_bytes > max_bytes do
          {:halt, {acc, bytes}}
        else
          {:cont, {[line | acc], new_bytes}}
        end
      end)

    lines_removed = total - length(kept)
    {kept, lines_removed}
  end
end
