defmodule Lantern.MCP.Tools.CheckHealth do
  @moduledoc "Check health status of projects"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.Health.Checker
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.System.Health

  schema do
    field(:name, :string, description: "Project name (omit for all projects)")
  end

  def execute(params, frame) do
    Timeout.run(frame, 10_000, fn ->
      if params[:name] do
        case Checker.get(params.name) do
          nil ->
            {:reply,
             Response.tool()
             |> Response.json(%{status: "unknown", message: "No health data for '#{params.name}'"}),
             frame}

          health ->
            {:reply, Response.tool() |> Response.json(health), frame}
        end
      else
        system = Health.status()
        projects = Checker.all()
        {:reply, Response.tool() |> Response.json(Map.put(system, :projects, projects)), frame}
      end
    end)
  end
end
