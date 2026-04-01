defmodule PiEx.SubAgent.Registry do
  @moduledoc """
  Global registry for named pre-defined subagent definitions.

  Started automatically by `PiEx.Application`. Backed by a public ETS table
  (`:subagent_registry`) for fast concurrent reads — no GenServer round-trip
  needed for lookups.

  Use `PiEx.Agent.Config.subagents` for per-agent inline definitions, or
  register globally here to share definitions across all agents.

  ## Example

      alias PiEx.SubAgent.{Definition, Registry}

      Registry.register(%Definition{
        name: "code_reviewer",
        description: "Reviews Elixir code for correctness, style, and security",
        system_prompt: "You are an expert Elixir code reviewer...",
        tools: []
      })

      {:ok, def} = Registry.lookup("code_reviewer")
  """

  use GenServer

  @table :subagent_registry

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Register a subagent definition. Overwrites any existing entry with the same name."
  @spec register(PiEx.SubAgent.Definition.t()) :: :ok
  def register(%PiEx.SubAgent.Definition{} = definition) do
    GenServer.call(__MODULE__, {:register, definition})
  end

  @doc "Look up a subagent definition by name."
  @spec lookup(String.t()) :: {:ok, PiEx.SubAgent.Definition.t()} | :not_found
  def lookup(name) do
    case :ets.lookup(@table, name) do
      [{^name, definition}] -> {:ok, definition}
      [] -> :not_found
    end
  end

  @doc "List all registered subagent definitions."
  @spec list() :: [PiEx.SubAgent.Definition.t()]
  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_name, definition} -> definition end)
  end

  @doc "Remove a registered subagent definition."
  @spec deregister(String.t()) :: :ok
  def deregister(name) do
    GenServer.call(__MODULE__, {:deregister, name})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, %PiEx.SubAgent.Definition{name: name} = definition}, _from, state) do
    :ets.insert(@table, {name, definition})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:deregister, name}, _from, state) do
    :ets.delete(@table, name)
    {:reply, :ok, state}
  end
end
