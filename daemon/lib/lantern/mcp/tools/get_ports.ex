defmodule Lantern.MCP.Tools.GetPorts do
  @moduledoc "Get port assignments for all projects"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.Projects.PortAllocator
  alias Lantern.Health.Checker

  schema do
  end

  def execute(_params, frame) do
    Timeout.run(frame, 10_000, fn ->
      assignments = PortAllocator.assignments()
      health = Checker.all()

      result =
        Map.new(assignments, fn {name, port} ->
          project_health = Map.get(health, name, %{})

          {name,
           %{
             port: port,
             health_status: Map.get(project_health, :status, "unknown")
           }}
        end)

      {:reply, Response.tool() |> Response.json(result), frame}
    end)
  end
end
