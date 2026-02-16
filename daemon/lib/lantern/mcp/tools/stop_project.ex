defmodule Lantern.MCP.Tools.StopProject do
  @moduledoc "Stop a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.Manager

  schema do
    field(:name, :string, required: true, description: "Project name")
  end

  def execute(%{name: name}, frame) do
    case Manager.get(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      _project ->
        case Manager.deactivate(name) do
          {:ok, updated_project} ->
            msg = "Stopped #{updated_project.name} (status: #{updated_project.status})"
            {:reply, Response.tool() |> Response.text(msg), frame}

          {:error, reason} ->
            {:error, Error.execution(inspect(reason)), frame}
        end
    end
  end
end
