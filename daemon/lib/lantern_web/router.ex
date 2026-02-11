defmodule LanternWeb.Router do
  use LanternWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LanternWeb do
    pipe_through :api

    # Projects
    get "/projects", ProjectController, :index
    post "/projects/scan", ProjectController, :scan
    get "/projects/:name", ProjectController, :show
    post "/projects/:name/activate", ProjectController, :activate
    post "/projects/:name/deactivate", ProjectController, :deactivate
    post "/projects/:name/restart", ProjectController, :restart
    put "/projects/:name", ProjectController, :update

    # Services
    get "/services", ServiceController, :index
    get "/services/:name/status", ServiceController, :status
    post "/services/:name/start", ServiceController, :start
    post "/services/:name/stop", ServiceController, :stop

    # System
    get "/system/health", SystemController, :health
    post "/system/init", SystemController, :init
    get "/system/settings", SystemController, :show_settings
    put "/system/settings", SystemController, :update_settings

    # Templates
    get "/templates", TemplateController, :index
    post "/templates", TemplateController, :create
    put "/templates/:name", TemplateController, :update
    delete "/templates/:name", TemplateController, :delete

    # Profiles
    get "/profiles", ProfileController, :index
    post "/profiles/:name/activate", ProfileController, :activate
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:lantern, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: LanternWeb.Telemetry
    end
  end
end
