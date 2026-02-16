defmodule Lantern.MCP.Tools.GetProjectEndpoints do
  @moduledoc "List API endpoints for a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  schema do
    field(:name, :string, required: true, description: "Project name")
  end

  def execute(%{name: name}, frame) do
    case Manager.get(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      project ->
        {:reply, Response.tool() |> Response.json(Project.merged_endpoints(project)), frame}
    end
  end
end
