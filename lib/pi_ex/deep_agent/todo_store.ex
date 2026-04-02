defmodule PiEx.DeepAgent.TodoStore do
  @moduledoc """
  GenServer that owns an ETS table for per-agent in-memory todo lists.

  Each agent run is assigned a `list_id`. Items are stored as
  `{list_id, item_id} => item_map` entries. The list is automatically
  deleted when the agent process exits (see `PiEx.DeepAgent.start/1`).
  """

  use GenServer

  @table :todo_store
  @valid_statuses ~w(pending in_progress done cancelled)

  # --- Public API ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Create a new todo item with `:pending` status."
  @spec create(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def create(list_id, title, description \\ "") do
    GenServer.call(__MODULE__, {:create, list_id, title, description})
  end

  @doc "Update fields of an existing todo item. `changes` keys: `\"status\"`, `\"title\"`, `\"description\"`."
  @spec update(String.t(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def update(list_id, item_id, changes) do
    GenServer.call(__MODULE__, {:update, list_id, item_id, changes})
  end

  @doc "List all todo items for a `list_id`, sorted by creation time. Direct ETS read."
  @spec list(String.t()) :: [map()]
  def list(list_id) do
    @table
    |> :ets.match_object({{list_id, :_}, :_})
    |> Enum.map(fn {_key, item} -> item end)
    |> Enum.sort_by(& &1.created_at, DateTime)
  end

  @doc "Delete all todo items for a `list_id`."
  @spec delete_list(String.t()) :: :ok
  def delete_list(list_id) do
    GenServer.call(__MODULE__, {:delete_list, list_id})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create, list_id, title, description}, _from, state) do
    item_id = generate_id()

    item = %{
      id: item_id,
      title: title,
      description: description,
      status: :pending,
      created_at: DateTime.utc_now()
    }

    :ets.insert(@table, {{list_id, item_id}, item})
    {:reply, {:ok, item}, state}
  end

  @impl true
  def handle_call({:update, list_id, item_id, changes}, _from, state) do
    key = {list_id, item_id}

    case :ets.lookup(@table, key) do
      [{^key, item}] ->
        case apply_changes(item, changes) do
          {:ok, updated} ->
            :ets.insert(@table, {key, updated})
            {:reply, {:ok, updated}, state}

          {:error, _} = err ->
            {:reply, err, state}
        end

      [] ->
        {:reply, {:error, "todo item not found: #{item_id}"}, state}
    end
  end

  @impl true
  def handle_call({:delete_list, list_id}, _from, state) do
    :ets.match_delete(@table, {{list_id, :_}, :_})
    {:reply, :ok, state}
  end

  # --- Private helpers ---

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp apply_changes(item, changes) do
    Enum.reduce_while(changes, {:ok, item}, fn
      {"status", val}, {:ok, acc} ->
        case parse_status(val) do
          {:ok, status} -> {:cont, {:ok, Map.put(acc, :status, status)}}
          err -> {:halt, err}
        end

      {"title", val}, {:ok, acc} when is_binary(val) and val != "" ->
        {:cont, {:ok, Map.put(acc, :title, val)}}

      {"description", val}, {:ok, acc} when is_binary(val) ->
        {:cont, {:ok, Map.put(acc, :description, val)}}

      {key, _val}, _ ->
        {:halt, {:error, "unknown field: #{key}"}}
    end)
  end

  defp parse_status("pending"), do: {:ok, :pending}
  defp parse_status("in_progress"), do: {:ok, :in_progress}
  defp parse_status("done"), do: {:ok, :done}
  defp parse_status("cancelled"), do: {:ok, :cancelled}

  defp parse_status(s) do
    {:error, "invalid status: #{s}. Must be one of: #{Enum.join(@valid_statuses, ", ")}"}
  end
end
