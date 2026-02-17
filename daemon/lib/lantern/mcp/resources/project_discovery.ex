defmodule Lantern.MCP.Resources.ProjectDiscovery do
  @moduledoc "Discovery metadata for all projects"
  use Hermes.Server.Component,
    type: :resource,
    uri: "lantern:///projects/discovery"

  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  def read(_params, frame) do
    content =
      Manager.list()
      |> Enum.map(fn project ->
        %{
          name: project.name,
          docs_auto: project.docs_auto || %{},
          api_auto: project.api_auto || %{},
          discovered_docs: project.discovered_docs || [],
          discovered_endpoints: project.discovered_endpoints || [],
          docs_available: Project.merged_docs(project),
          endpoints_available: Project.merged_endpoints(project),
          discovery: project.discovery || %{}
        }
      end)

    {:reply, Response.resource() |> Response.text(Jason.encode!(content)), frame}
  end
end
