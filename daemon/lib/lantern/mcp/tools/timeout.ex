defmodule Lantern.MCP.Tools.Timeout do
  @moduledoc """
  Wraps MCP tool execution with wall-clock timeouts, cancellation support,
  and progress notifications.

  Features:
  - Hard wall-clock timeout prevents tools from hanging indefinitely
  - Listens for MCP `notifications/cancelled` and aborts immediately
  - Sends periodic `notifications/progress` to signal liveness
  """

  alias Hermes.MCP.Error
  alias Lantern.MCP.InFlight

  @progress_interval 3_000

  @doc """
  Runs `fun` inside a supervised task with timeout, cancellation, and progress.

  `fun` must return a standard MCP result tuple, e.g.
  `{:reply, response, frame}` or `{:error, error, frame}`.

  Extracts the request_id from `frame.request.id` for cancellation tracking,
  and the progressToken from `frame.request.params["_meta"]["progressToken"]`
  for progress notifications.
  """
  def run(frame, timeout_ms, fun) do
    request_id = get_request_id(frame)
    progress_token = get_progress_token(frame)

    task = Task.Supervisor.async_nolink(Lantern.TaskSupervisor, fun)

    # Register for cancellation
    if request_id, do: InFlight.register(request_id, task.pid)

    # Start progress ticker for long-running tools
    ticker =
      if progress_token && timeout_ms > @progress_interval do
        start_progress_ticker(frame, progress_token, timeout_ms)
      end

    result =
      case Task.yield(task, timeout_ms) || Task.shutdown(task, 5_000) do
        {:ok, result} ->
          result

        {:exit, :cancelled} ->
          {:error, Error.execution("Cancelled by client"), frame}

        {:exit, reason} ->
          {:error, Error.execution(format_exit(reason)), frame}

        nil ->
          {:error, Error.execution("Timed out after #{div(timeout_ms, 1000)}s"), frame}
      end

    # Cleanup
    if request_id, do: InFlight.deregister(request_id)
    if ticker, do: stop_progress_ticker(ticker)

    result
  end

  # Extract request ID from frame for cancellation tracking
  defp get_request_id(%{request: %{id: id}}) when not is_nil(id), do: id
  defp get_request_id(_frame), do: nil

  # Extract progress token from request _meta
  defp get_progress_token(%{request: %{params: %{"_meta" => %{"progressToken" => token}}}})
       when not is_nil(token),
       do: token

  defp get_progress_token(_frame), do: nil

  # Progress ticker — sends periodic progress notifications to signal liveness
  defp start_progress_ticker(frame, progress_token, timeout_ms) do
    total_steps = div(timeout_ms, @progress_interval)
    parent = self()

    spawn_link(fn ->
      ticker_loop(frame, progress_token, 1, total_steps, parent)
    end)
  end

  defp ticker_loop(frame, progress_token, step, total_steps, parent) do
    Process.sleep(@progress_interval)

    if Process.alive?(parent) do
      try do
        Hermes.Server.send_progress(frame, progress_token, step,
          total: total_steps,
          message: "Working... (#{step * div(@progress_interval, 1000)}s elapsed)"
        )
      rescue
        _ -> :ok
      end

      if step < total_steps do
        ticker_loop(frame, progress_token, step + 1, total_steps, parent)
      end
    end
  end

  defp stop_progress_ticker(pid) when is_pid(pid) do
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
  end

  defp format_exit({:timeout, {GenServer, :call, _}}), do: "Service unavailable (GenServer timeout)"
  defp format_exit(reason), do: "Operation failed: #{inspect(reason)}"
end
