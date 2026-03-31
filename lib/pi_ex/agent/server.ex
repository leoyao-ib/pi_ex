defmodule PiEx.Agent.Server do
  @moduledoc """
  Stateful GenServer that orchestrates an agent run.

  Lifecycle:
  1. Started via `PiEx.Agent.Supervisor.start_agent/1`.
  2. Callers subscribe via `subscribe/2` to receive agent events.
  3. `prompt/2` starts a run. Returns `{:error, :already_running}` if busy.
  4. `steer/2` injects messages mid-run (queued, polled each turn).
  5. `follow_up/2` injects messages when the agent would otherwise stop.
  6. `abort/1` signals cancellation to the running task.
  7. Events arrive as `{:agent_event, event}` in the subscriber's mailbox.

  ## State
  - `:status` — `:idle | :running`
  - `:messages` — full conversation transcript
  - `:subscribers` — list of PIDs to notify
  - `:loop_task` — the running `Task` struct (if any)
  - `:steering_queue` — messages to inject on the next turn
  - `:follow_up_queue` — messages to inject after the agent stops
  """

  use GenServer

  alias PiEx.Agent.{Config, Loop}

  defstruct [
    :config,
    status: :idle,
    messages: [],
    subscribers: [],
    loop_task: nil,
    steering_queue: [],
    follow_up_queue: []
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc "Subscribe `pid` to receive `{:agent_event, event}` messages. Default: `self()`."
  @spec subscribe(pid(), pid()) :: :ok
  def subscribe(server, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  @doc "Start a new run with the given prompt text or messages. Returns `{:error, :already_running}` if busy."
  @spec prompt(pid(), String.t() | [PiEx.AI.Message.t()]) :: :ok | {:error, :already_running}
  def prompt(server, text) when is_binary(text) do
    msg = PiEx.AI.Message.user(text)
    GenServer.call(server, {:prompt, [msg]})
  end

  def prompt(server, messages) when is_list(messages) do
    GenServer.call(server, {:prompt, messages})
  end

  @doc "Inject messages to steer the agent mid-run (queued for next turn)."
  @spec steer(pid(), PiEx.AI.Message.t() | [PiEx.AI.Message.t()]) :: :ok
  def steer(server, msg) when is_struct(msg) do
    GenServer.cast(server, {:steer, [msg]})
  end

  def steer(server, messages) when is_list(messages) do
    GenServer.cast(server, {:steer, messages})
  end

  @doc "Inject follow-up messages to restart the agent after it stops."
  @spec follow_up(pid(), PiEx.AI.Message.t() | [PiEx.AI.Message.t()]) :: :ok
  def follow_up(server, msg) when is_struct(msg) do
    GenServer.cast(server, {:follow_up, [msg]})
  end

  def follow_up(server, messages) when is_list(messages) do
    GenServer.cast(server, {:follow_up, messages})
  end

  @doc "Abort the currently running loop (no-op if idle)."
  @spec abort(pid()) :: :ok
  def abort(server) do
    GenServer.cast(server, :abort)
  end

  @doc "Return the current message transcript."
  @spec get_messages(pid()) :: [PiEx.AI.Message.t()]
  def get_messages(server) do
    GenServer.call(server, :get_messages)
  end

  @doc "Return current status: `:idle` or `:running`."
  @spec status(pid()) :: :idle | :running
  def status(server) do
    GenServer.call(server, :status)
  end

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(%Config{} = config) do
    state = %__MODULE__{
      config: inject_queue_hooks(config, self())
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call({:prompt, _messages}, _from, %{status: :running} = state) do
    {:reply, {:error, :already_running}, state}
  end

  @impl true
  def handle_call({:prompt, messages}, _from, state) do
    all_messages = state.messages ++ messages
    server_pid = self()

    task =
      Task.Supervisor.async_nolink(PiEx.TaskSupervisor, fn ->
        Loop.run(all_messages, state.config, server_pid)
      end)

    # Monitor the task so we catch crashes
    Process.monitor(task.pid)

    {:reply, :ok, %{state | status: :running, loop_task: task, messages: all_messages}}
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:get_steering_messages, _from, state) do
    msgs = state.steering_queue
    {:reply, msgs, %{state | steering_queue: []}}
  end

  @impl true
  def handle_call(:get_follow_up_messages, _from, state) do
    msgs = state.follow_up_queue
    {:reply, msgs, %{state | follow_up_queue: []}}
  end

  @impl true
  def handle_cast({:steer, messages}, state) do
    {:noreply, %{state | steering_queue: state.steering_queue ++ messages}}
  end

  @impl true
  def handle_cast({:follow_up, messages}, state) do
    {:noreply, %{state | follow_up_queue: state.follow_up_queue ++ messages}}
  end

  @impl true
  def handle_cast(:abort, %{loop_task: nil} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:abort, %{loop_task: task} = state) do
    Task.shutdown(task, :brutal_kill)
    {:noreply, %{state | status: :idle, loop_task: nil}}
  end

  @impl true
  def handle_info({:agent_event, event}, state) do
    state = apply_event(event, state)
    broadcast(state.subscribers, {:agent_event, event})
    {:noreply, state}
  end

  # Task completed normally (async_nolink sends a message with the result)
  @impl true
  def handle_info({ref, _result}, %{loop_task: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | status: :idle, loop_task: nil}}
  end

  # Task crashed
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{loop_task: task} = state)
      when task != nil and task.pid == pid do
    if reason != :normal do
      broadcast(state.subscribers, {:agent_event, {:agent_error, reason}})
    end

    {:noreply, %{state | status: :idle, loop_task: nil}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # State reduction
  # ---------------------------------------------------------------------------

  defp apply_event({:agent_end, messages}, state) do
    %{state | messages: messages, status: :idle}
  end

  defp apply_event(_event, state), do: state

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp broadcast(subscribers, message) do
    Enum.each(subscribers, &send(&1, message))
  end

  # Inject queue-polling hooks so the loop can call back into this GenServer
  defp inject_queue_hooks(%Config{} = config, server_pid) do
    %{
      config
      | get_steering_messages: fn -> GenServer.call(server_pid, :get_steering_messages) end,
        get_follow_up_messages: fn -> GenServer.call(server_pid, :get_follow_up_messages) end
    }
  end
end
