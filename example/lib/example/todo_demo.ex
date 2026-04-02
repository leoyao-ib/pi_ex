defmodule Example.TodoDemo do
  @moduledoc """
  Demonstration of the built-in todo list tools in `PiEx.DeepAgent`.

  The agent is given a small coding task and asked to manage its own progress
  using `todo_create`, `todo_update`, and `todo_list`.

  ## Running

      cd example && mix run -e "Example.TodoDemo.run()"

  Requires the OpenAI API key to be set:

      export OPENAI_API_KEY=sk-...
  """

  alias PiEx.AI.{Model, ProviderParams}

  @model Model.new("gpt-4.1", "openai",
           provider_params: %ProviderParams.OpenAI{
             http_receive_timeout: 180_000
           }
         )

  @doc "Run the todo demo and return the final messages."
  @spec run() :: [PiEx.AI.Message.t()]
  def run do
    project_root = Path.expand("../..", __DIR__)
    config = %PiEx.DeepAgent.Config{model: @model, project_root: project_root}

    {:ok, agent} = PiEx.DeepAgent.start(config)
    PiEx.Agent.subscribe(agent)
    :ok = PiEx.Agent.prompt(agent, prompt())

    messages = collect_events()
    PiEx.Agent.stop(agent)
    messages
  end

  defp prompt do
    """
    You have access to todo list tools: todo_create, todo_update, and todo_list.

    Please complete the following exercise to demonstrate the todo tools:

    1. Create 3 todo items:
       - "Explore project structure" with description "Use ls and find tools"
       - "Read mix.exs" with description "Check dependencies and config"
       - "Write summary" with description "Write a brief summary file"

    2. List all todos to confirm they were created.

    3. Mark "Explore project structure" as in_progress, then use the ls tool
       to list the project root (path "."), then mark it as done.

    4. Mark "Read mix.exs" as in_progress, then use the read tool to read
       mix.exs, then mark it as done.

    5. Mark "Write summary" as in_progress, then use the write tool to create
       a file called TODO_DEMO_OUTPUT.md with a short summary of what you found,
       then mark it as done.

    6. Use todo_list to show the final state of all todos.

    Use the todo tools at each step as described above.
    """
  end

  defp collect_events do
    receive do
      {:agent_event, :agent_start} ->
        IO.puts("\n[Agent started]\n")
        collect_events()

      {:agent_event, {:message_update, _msg, {:text_delta, _idx, delta, _partial}}} ->
        IO.write(delta)
        collect_events()

      {:agent_event, {:tool_execution_start, _id, name, args}} ->
        IO.puts("\n\n[Tool: #{name}] #{inspect(args, limit: 5)}")
        collect_events()

      {:agent_event, {:tool_execution_end, _id, name, _result, is_error}} ->
        status = if is_error, do: "ERROR", else: "ok"
        IO.puts("[Done: #{name}] → #{status}")
        collect_events()

      {:agent_event, {:agent_end, messages}} ->
        IO.puts("\n\n[Agent done — #{length(messages)} messages]\n")
        messages

      {:agent_event, _other} ->
        collect_events()
    after
      180_000 ->
        IO.puts("\n[Timeout]\n")
        []
    end
  end
end
