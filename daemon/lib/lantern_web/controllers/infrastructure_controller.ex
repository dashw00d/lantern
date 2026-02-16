defmodule LanternWeb.InfrastructureController do
  use LanternWeb, :controller

  alias Lantern.Projects.{Manager, PortAllocator}
  alias Lantern.Health.Checker

  def ports(conn, _params) do
    assignments = PortAllocator.assignments()
    health = Checker.all()

    ports =
      Map.new(assignments, fn {name, port} ->
        project_health = Map.get(health, name, %{})

        {name,
         %{
           port: port,
           health_status: Map.get(project_health, :status, "unknown")
         }}
      end)

    json(conn, %{data: ports})
  end

  def dependencies(conn, _params) do
    projects = Manager.list()

    graph =
      Enum.reduce(projects, %{}, fn project, acc ->
        deps = project.depends_on || []

        dependents =
          projects
          |> Enum.filter(fn p -> project.name in (p.depends_on || []) end)
          |> Enum.map(& &1.name)

        Map.put(acc, project.name, %{
          depends_on: deps,
          depended_by: dependents
        })
      end)

    json(conn, %{data: graph})
  end
end
