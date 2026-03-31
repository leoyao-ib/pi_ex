defmodule PiEx.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: PiEx.TaskSupervisor},
      {DynamicSupervisor, name: PiEx.Agent.Supervisor, strategy: :one_for_one},
      PiEx.DeepAgent.FileMutex
    ]

    opts = [strategy: :one_for_one, name: PiEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
