defmodule LanternWeb.Router do
  use LanternWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", LanternWeb do
    pipe_through(:api)

    # Projects
    get("/projects", ProjectController, :index)
    post("/projects", ProjectController, :create)
    post("/projects/scan", ProjectController, :scan)
    get("/projects/:name", ProjectController, :show)
    get("/projects/:name/logs", ProjectController, :logs)
    get("/projects/:name/endpoints", ProjectController, :endpoints)
    get("/projects/:name/discovery", ProjectController, :discovery)
    get("/projects/:name/dependencies", ProjectController, :dependencies)
    get("/projects/:name/dependents", ProjectController, :dependents)
    post("/projects/:name/discovery/refresh", ProjectController, :refresh_discovery)
    post("/projects/discovery/refresh", ProjectController, :refresh_discovery_all)
    post("/projects/:name/activate", ProjectController, :activate)
    post("/projects/:name/deactivate", ProjectController, :deactivate)
    post("/projects/:name/restart", ProjectController, :restart)
    post("/projects/:name/reset", ProjectController, :reset)
    put("/projects/:name", ProjectController, :update)
    patch("/projects/:name", ProjectController, :patch)
    delete("/projects/:name", ProjectController, :delete)

    # Tools
    get("/tools", ToolController, :index)
    get("/tools/:id", ToolController, :show)
    get("/tools/:id/docs", ToolController, :docs)

    # Runtime command endpoints (from project deploy/start-stop-restart/logs/status config)
    post("/projects/:name/deploy/start", DeployController, :start)
    post("/projects/:name/deploy/stop", DeployController, :stop)
    post("/projects/:name/deploy/restart", DeployController, :restart)
    get("/projects/:name/deploy/logs", DeployController, :logs)
    get("/projects/:name/deploy/status", DeployController, :status)

    # Docs
    get("/projects/:name/docs", DocController, :index)
    get("/projects/:name/docs/*filename", DocController, :show)

    # Health
    get("/health", HealthController, :index)
    get("/projects/:name/health", HealthController, :show)
    post("/projects/:name/health/check", HealthController, :check)

    # Infrastructure
    get("/ports", InfrastructureController, :ports)
    get("/dependencies", InfrastructureController, :dependencies)

    # Services
    get("/services", ServiceController, :index)
    get("/services/:name/status", ServiceController, :status)
    post("/services/:name/start", ServiceController, :start)
    post("/services/:name/stop", ServiceController, :stop)

    # System
    get("/system/health", SystemController, :health)
    post("/system/init", SystemController, :init)
    post("/system/shutdown", SystemController, :shutdown)
    get("/system/settings", SystemController, :show_settings)
    put("/system/settings", SystemController, :update_settings)

    # Templates
    get("/templates", TemplateController, :index)
    post("/templates", TemplateController, :create)
    put("/templates/:name", TemplateController, :update)
    delete("/templates/:name", TemplateController, :delete)

    # Profiles
    get("/profiles", ProfileController, :index)
    post("/profiles/:name/activate", ProfileController, :activate)
  end

  # Root API discovery
  scope "/", LanternWeb do
    pipe_through(:api)
    get("/", RootController, :index)
  end

  scope "/", LanternWeb do
    get("/:project/docs", LighthouseController, :index)
    get("/:project/docs/*filename", LighthouseController, :show)
  end

  # MCP endpoint
  forward("/mcp", Hermes.Server.Transport.StreamableHTTP.Plug,
    server: Lantern.MCP.Server
  )

  # Enable LiveDashboard in development
  if Application.compile_env(:lantern, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: LanternWeb.Telemetry)
    end
  end
end
