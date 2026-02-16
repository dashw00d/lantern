defmodule LanternWeb.RootController do
  use LanternWeb, :controller

  @version Mix.Project.config()[:version]

  def index(conn, _params) do
    json(conn, %{
      name: "lantern",
      version: @version,
      description: "Lantern — local development environment manager",
      endpoints: %{
        projects: "/api/projects",
        project_discovery: "/api/projects/:name/discovery",
        tools: "/api/tools",
        services: "/api/services",
        health: "/api/health",
        system: "/api/system/health",
        shutdown: "/api/system/shutdown",
        settings: "/api/system/settings",
        templates: "/api/templates",
        profiles: "/api/profiles",
        ports: "/api/ports",
        dependencies: "/api/dependencies",
        mcp: "/mcp"
      }
    })
  end
end
