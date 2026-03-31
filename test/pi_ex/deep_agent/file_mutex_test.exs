defmodule PiEx.DeepAgent.FileMutexTest do
  use ExUnit.Case, async: false

  alias PiEx.DeepAgent.FileMutex

  setup do
    {:ok, _pid} = start_supervised({FileMutex, name: :test_file_mutex})
    :ok
  end

  describe "with_lock/3" do
    test "sequential execution on same path" do
      parent = self()
      path = "/tmp/test_mutex_seq_#{:erlang.unique_integer([:positive])}"

      # task1 acquires lock, signals its inner PID, waits for permission
      outer1 =
        Task.async(fn ->
          FileMutex.with_lock(
            path,
            fn ->
              send(parent, {:inner_pid, self()})
              receive do: (:proceed -> :ok)
              send(parent, :task1_done)
              1
            end,
            :test_file_mutex
          )
        end)

      # Receive the inner task's PID so we can signal it
      assert_receive {:inner_pid, inner_pid}, 1000

      # task2 should be queued while task1 holds the lock
      outer2 =
        Task.async(fn ->
          FileMutex.with_lock(
            path,
            fn ->
              send(parent, :task2_ran)
              2
            end,
            :test_file_mutex
          )
        end)

      # Give task2 time to enqueue
      Process.sleep(50)

      # Release task1
      send(inner_pid, :proceed)
      assert_receive :task1_done, 1000
      assert_receive :task2_ran, 1000

      assert Task.await(outer1) == 1
      assert Task.await(outer2) == 2
    end

    test "independent paths are not blocked by each other" do
      parent = self()
      path1 = "/tmp/test_mutex_ind1_#{:erlang.unique_integer([:positive])}"
      path2 = "/tmp/test_mutex_ind2_#{:erlang.unique_integer([:positive])}"

      outer1 =
        Task.async(fn ->
          FileMutex.with_lock(
            path1,
            fn ->
              send(parent, {:inner_pid, self()})
              receive do: (:proceed -> :ok)
              :path1_done
            end,
            :test_file_mutex
          )
        end)

      assert_receive {:inner_pid, inner_pid}, 1000

      # path2 should NOT be blocked by path1's lock
      outer2 =
        Task.async(fn ->
          FileMutex.with_lock(path2, fn -> :path2_done end, :test_file_mutex)
        end)

      assert Task.await(outer2, 1000) == :path2_done

      send(inner_pid, :proceed)
      assert Task.await(outer1, 1000) == :path1_done
    end

    test "returns the result of fun" do
      path = "/tmp/test_mutex_result_#{:erlang.unique_integer([:positive])}"
      result = FileMutex.with_lock(path, fn -> {:ok, 42} end, :test_file_mutex)
      assert result == {:ok, 42}
    end
  end
end
