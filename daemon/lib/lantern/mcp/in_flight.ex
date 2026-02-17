defmodule Lantern.MCP.InFlight do
  @moduledoc """
  Tracks in-flight MCP tool tasks and handles cancellation.

  When a tool call starts via `Timeout.run`, it registers the task PID
  with the request_id. When Claude Code sends `notifications/cancelled`,
  a telemetry handler looks up the task and kills it immediately instead
  of waiting for the full timeout.
  """

  use GenServer

  require Logger

  @table :mcp_in_flight

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Register an in-flight task by request_id"
  def register(request_id, task_pid) when is_pid(task_pid) do
    :ets.insert(@table, {request_id, task_pid, System.monotonic_time(:millisecond)})
    :ok
  end

  @doc "Deregister when task completes normally"
  def deregister(request_id) do
    :ets.delete(@table, request_id)
    :ok
  end

  @doc "Cancel an in-flight task by request_id (kills the task)"
  def cancel(request_id) do
    case :ets.lookup(@table, request_id) do
      [{^request_id, task_pid, _started_at}] ->
        Logger.info("[MCP.InFlight] Cancelling task for request #{request_id}")
        Process.exit(task_pid, :cancelled)
        :ets.delete(@table, request_id)
        :ok

      [] ->
        :not_found
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    attach_telemetry()
    {:ok, %{}}
  end

  # Telemetry handler — listens for cancellation notifications from Hermes

  defp attach_telemetry do
    :telemetry.attach(
      "lantern-mcp-cancellation",
      [:hermes_mcp, :server, :notification],
      &handle_telemetry_event/4,
      nil
    )
  end

  @doc false
  def handle_telemetry_event(
        [:hermes_mcp, :server, :notification],
        _measurements,
        %{method: "cancelled", request_id: request_id},
        _config
      ) do
    cancel(request_id)
  end

  def handle_telemetry_event(_event, _measurements, _metadata, _config), do: :ok
end
