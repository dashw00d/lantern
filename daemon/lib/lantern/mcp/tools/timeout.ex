defmodule Lantern.MCP.Tools.Timeout do
  @moduledoc """
  Wraps MCP tool execution with a wall-clock timeout.

  Prevents tools from hanging indefinitely when downstream GenServers
  are blocked or HTTP services are unreachable.
  """

  alias Hermes.MCP.Error

  @doc """
  Runs `fun` inside a supervised task with a hard timeout.

  `fun` must return a standard MCP result tuple, e.g.
  `{:reply, response, frame}` or `{:error, error, frame}`.

  On timeout or crash, returns a clean MCP error.
  """
  def run(frame, timeout_ms, fun) do
    task = Task.Supervisor.async_nolink(Lantern.TaskSupervisor, fun)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      {:exit, reason} ->
        {:error, Error.execution(format_exit(reason)), frame}

      nil ->
        {:error, Error.execution("Timed out after #{div(timeout_ms, 1000)}s"), frame}
    end
  end

  defp format_exit({:timeout, {GenServer, :call, _}}), do: "Service unavailable (GenServer timeout)"
  defp format_exit(reason), do: "Operation failed: #{inspect(reason)}"
end
