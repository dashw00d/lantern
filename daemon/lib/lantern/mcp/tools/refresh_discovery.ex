defmodule Lantern.MCP.Tools.RefreshDiscovery do
  @moduledoc "Refresh docs/API discovery metadata for one project or all projects"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  schema do
    field(:name, :string, description: "Project name or ID (omit to refresh all)")
  end

  def execute(params, frame) do
    case params[:name] do
      nil ->
        case Manager.refresh_discovery(:all) do
          {:ok, projects} ->
            payload = Enum.map(projects, &Project.to_map/1)
            {:reply, Response.tool() |> Response.json(payload), frame}

          {:error, reason} ->
            {:error, Error.execution("Failed to refresh discovery: #{inspect(reason)}"), frame}
        end

      name ->
        project = Manager.get(name) || Manager.get_by_id(name)

        case project do
          nil ->
            {:error, Error.execution("Project '#{name}' not found"), frame}

          found ->
            case Manager.refresh_discovery(found.name) do
              {:ok, refreshed} ->
                {:reply, Response.tool() |> Response.json(Project.to_map(refreshed)), frame}

              {:error, reason} ->
                {:error, Error.execution("Failed to refresh discovery: #{inspect(reason)}"),
                 frame}
            end
        end
    end
  end
end
