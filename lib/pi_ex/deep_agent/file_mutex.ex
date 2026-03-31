defmodule PiEx.DeepAgent.FileMutex do
  @moduledoc """
  GenServer that serializes write/edit operations per absolute file path.

  Ensures at most one writer operates on a given path at a time; additional
  callers are queued and served in order. Independent paths run concurrently
  via `PiEx.TaskSupervisor`.
  """

  use GenServer

  # State:
  #   queues:  %{path => [{from, fun}]}  — pending callers per path
  #   running: MapSet.t(path)            — paths currently locked
  #   pending: %{task_ref => {path, from}} — in-flight tasks

  # --- Public API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Run `fun.()` exclusively for `path`. Queues the caller if the path is locked.

  Returns the result of `fun.()`.
  """
  @spec with_lock(String.t(), (-> any()), GenServer.server()) :: any()
  def with_lock(path, fun, server \\ __MODULE__) do
    GenServer.call(server, {:with_lock, path, fun}, :infinity)
  end

  # --- Callbacks ---

  @impl true
  def init(:ok) do
    {:ok, %{queues: %{}, running: MapSet.new(), pending: %{}}}
  end

  @impl true
  def handle_call({:with_lock, path, fun}, from, state) do
    if MapSet.member?(state.running, path) do
      queue = Map.get(state.queues, path, [])
      {:noreply, %{state | queues: Map.put(state.queues, path, queue ++ [{from, fun}])}}
    else
      {:noreply, start_task(path, from, fun, state)}
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.pop(state.pending, ref) do
      {nil, _} ->
        {:noreply, state}

      {{path, from}, new_pending} ->
        Process.demonitor(ref, [:flush])
        GenServer.reply(from, result)
        new_running = MapSet.delete(state.running, path)
        next_state = %{state | pending: new_pending, running: new_running}

        case Map.get(state.queues, path, []) do
          [] ->
            {:noreply, next_state}

          [{next_from, next_fun} | rest] ->
            new_queues = Map.put(next_state.queues, path, rest)
            {:noreply, start_task(path, next_from, next_fun, %{next_state | queues: new_queues})}
        end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # --- Private helpers ---

  defp start_task(path, from, fun, state) do
    task =
      Task.Supervisor.async_nolink(PiEx.TaskSupervisor, fn ->
        try do
          fun.()
        rescue
          e -> {:error, Exception.message(e)}
        end
      end)

    %{
      state
      | running: MapSet.put(state.running, path),
        pending: Map.put(state.pending, task.ref, {path, from})
    }
  end
end
