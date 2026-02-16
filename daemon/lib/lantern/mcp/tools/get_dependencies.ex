defmodule Lantern.MCP.Tools.GetDependencies do
  @moduledoc "Get dependency graph for all projects"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.Projects.Manager

  schema do
    field :name, :string, description: "Project name (omit for full graph)"
  end

  def execute(params, frame) do
    projects = Manager.list()

    graph =
      Enum.reduce(projects, %{}, fn project, acc ->
        deps = project.depends_on || []

        dependents =
          projects
          |> Enum.filter(fn p -> project.name in (p.depends_on || []) end)
          |> Enum.map(& &1.name)

        Map.put(acc, project.name, %{depends_on: deps, depended_by: dependents})
      end)

    result =
      if params[:name] do
        Map.get(graph, params.name, %{depends_on: [], depended_by: []})
      else
        graph
      end

    {:reply, Response.tool() |> Response.json(result), frame}
  end
end
