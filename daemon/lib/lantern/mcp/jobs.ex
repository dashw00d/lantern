defmodule Lantern.MCP.Jobs do
  @moduledoc """
  Stores results for async MCP tool jobs (fire-and-poll pattern).

  When `call_tool_api` is called with `async: true`, the HTTP request
  runs in the background and results are stored here. The agent then
  polls with `get_job_result` to retrieve the result.

  Jobs are automatically cleaned up after a TTL.
  """

  use GenServer

  require Logger

  @cleanup_interval 60_000
  @job_ttl 300_000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Submit an async job. Returns the job_id immediately."
  def submit(fun) when is_function(fun, 0) do
    job_id = generate_id()
    GenServer.cast(__MODULE__, {:submit, job_id, fun})
    job_id
  end

  @doc "Get a job's current status and result."
  def get(job_id) do
    GenServer.call(__MODULE__, {:get, job_id})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{jobs: %{}}}
  end

  @impl true
  def handle_cast({:submit, job_id, fun}, state) do
    task =
      Task.Supervisor.async_nolink(Lantern.TaskSupervisor, fn ->
        try do
          fun.()
        rescue
          e -> {:error, Exception.message(e)}
        catch
          :exit, reason -> {:error, inspect(reason)}
        end
      end)

    job = %{
      status: :running,
      task: task,
      result: nil,
      created_at: System.monotonic_time(:millisecond)
    }

    {:noreply, %{state | jobs: Map.put(state.jobs, job_id, job)}}
  end

  @impl true
  def handle_call({:get, job_id}, _from, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :running, task: task} = job ->
        # Check if task has completed
        case Task.yield(task, 0) do
          {:ok, result} ->
            updated = %{job | status: :completed, result: result, task: nil}
            jobs = Map.put(state.jobs, job_id, updated)
            {:reply, {:ok, updated.status, result}, %{state | jobs: jobs}}

          {:exit, reason} ->
            updated = %{job | status: :failed, result: {:error, inspect(reason)}, task: nil}
            jobs = Map.put(state.jobs, job_id, updated)
            {:reply, {:ok, updated.status, updated.result}, %{state | jobs: jobs}}

          nil ->
            elapsed = System.monotonic_time(:millisecond) - job.created_at
            {:reply, {:ok, :running, %{elapsed_ms: elapsed}}, state}
        end

      %{status: status, result: result} ->
        {:reply, {:ok, status, result}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    jobs =
      state.jobs
      |> Enum.reject(fn {_id, job} ->
        job.status != :running && now - job.created_at > @job_ttl
      end)
      |> Map.new()

    schedule_cleanup()
    {:noreply, %{state | jobs: jobs}}
  end

  def handle_info({ref, _result}, state) when is_reference(ref) do
    # Task completion message — ignore, we check via Task.yield in handle_call
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task monitor DOWN message — ignore
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
