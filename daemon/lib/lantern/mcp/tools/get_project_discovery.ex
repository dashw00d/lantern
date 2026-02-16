defmodule Lantern.MCP.Tools.GetProjectDiscovery do
  @moduledoc "Get discovery configuration and discovered docs/APIs for a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  schema do
    field(:name, :string, required: true, description: "Project name or ID")
  end

  def execute(%{name: name}, frame) do
    case Manager.get(name) || Manager.get_by_id(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      project ->
        payload = %{
          name: project.name,
          docs_auto: project.docs_auto || %{},
          api_auto: project.api_auto || %{},
          discovered_docs: project.discovered_docs || [],
          discovered_endpoints: project.discovered_endpoints || [],
          docs_available: Project.merged_docs(project),
          endpoints_available: Project.merged_endpoints(project),
          discovery: project.discovery || %{}
        }

        {:reply, Response.tool() |> Response.json(payload), frame}
    end
  end
end
