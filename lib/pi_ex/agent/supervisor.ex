defmodule PiEx.Agent.Supervisor do
  @moduledoc """
  DynamicSupervisor for agent processes.

  Started automatically by `PiEx.Application`. Use `start_agent/1` to spawn
  a supervised `PiEx.Agent.Server` at runtime.
  """

  @supervisor_name PiEx.Agent.Supervisor

  @doc """
  Starts a new supervised `PiEx.Agent.Server` with the given config.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start_agent(PiEx.Agent.Config.t()) :: {:ok, pid()} | {:error, term()}
  def start_agent(%PiEx.Agent.Config{} = config) do
    DynamicSupervisor.start_child(@supervisor_name, {PiEx.Agent.Server, config})
  end

  @doc "Lists all running agent server PIDs."
  @spec list_agents() :: [pid()]
  def list_agents do
    @supervisor_name
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  @doc "Terminates an agent server by PID."
  @spec stop_agent(pid()) :: :ok | {:error, :not_found}
  def stop_agent(pid) do
    DynamicSupervisor.terminate_child(@supervisor_name, pid)
  end
end
