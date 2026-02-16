defmodule Lantern.MCP.Tools.GetProjectLogs do
  @moduledoc "Get recent log output for a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, DeployRunner, ProcessRunner}

  schema do
    field(:name, :string, required: true, description: "Project name")
  end

  def execute(%{name: name}, frame) do
    case Manager.get(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      project ->
        # Try deploy logs first, fall back to local process runner logs
        case DeployRunner.execute(project, :logs) do
          {:ok, output} ->
            {:reply, Response.tool() |> Response.text(output), frame}

          _ ->
            logs = try_process_runner_logs(name)
            {:reply, Response.tool() |> Response.text(logs), frame}
        end
    end
  end

  defp try_process_runner_logs(name) do
    try do
      ProcessRunner.get_logs(name)
      |> Enum.join("\n")
    rescue
      _ -> "No logs available"
    catch
      :exit, _ -> "No logs available"
    end
  end
end
