defmodule Lantern.MCP.Tools.GetProject do
  @moduledoc "Get full detail for one project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.Projects.{Manager, Project}

  schema do
    field(:name, :string, required: true, description: "Project name or ID")
  end

  def execute(%{name: name}, frame) do
    Timeout.run(frame, 10_000, fn ->
      case Manager.get(name) || Manager.get_by_id(name) do
        nil ->
          {:error, Error.execution("Project '#{name}' not found"), frame}

        project ->
          {:reply, Response.tool() |> Response.json(Project.to_map(project)), frame}
      end
    end)
  end
end
