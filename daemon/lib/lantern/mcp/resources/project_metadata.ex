defmodule Lantern.MCP.Resources.ProjectMetadata do
  @moduledoc "All project metadata as JSON"
  use Hermes.Server.Component,
    type: :resource,
    uri: "lantern:///projects"

  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  def read(_params, frame) do
    projects =
      Manager.list()
      |> Enum.map(&Project.to_map/1)

    {:reply, Response.resource() |> Response.text(Jason.encode!(projects)), frame}
  end
end
