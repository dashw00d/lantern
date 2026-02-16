defmodule Lantern.SelfRegistration do
  @moduledoc """
  Registers the Lantern daemon as a tool in its own project registry,
  so it appears in /api/tools and gets a managed Caddy domain.
  """

  require Logger

  alias Lantern.Projects.Manager

  @lantern_name "lantern"
  @version Mix.Project.config()[:version]

  def register do
    case Manager.get(@lantern_name) do
      nil ->
        do_register()

      %{status: :running} ->
        Logger.debug("Lantern self-registration: already running")
        :ok

      _stopped ->
        Logger.info("Lantern self-registration: re-activating after restart")
        activate()
    end
  rescue
    e ->
      Logger.warning("Lantern self-registration failed: #{Exception.message(e)}")
      :ok
  end

  defp do_register do
    port =
      Application.get_env(:lantern, LanternWeb.Endpoint, [])
      |> Keyword.get(:http, [])
      |> Keyword.get(:port, 4777)
    tld = Application.get_env(:lantern, :tld, ".glow")

    attrs = %{
      name: @lantern_name,
      path: ".",
      kind: :tool,
      type: :proxy,
      description: "Lantern v#{@version} — local development environment manager",
      upstream_url: "http://127.0.0.1:#{port}",
      health_endpoint: "/api/system/health",
      domain: @lantern_name <> tld,
      tags: ["infrastructure", "internal"],
      enabled: true,
      endpoints: api_endpoints(),
      detection: %{confidence: :high, source: :self}
    }

    case Manager.register(attrs) do
      {:ok, _project} ->
        Logger.info("Lantern self-registration: registered")
        activate()

      {:error, :already_exists} ->
        Logger.debug("Lantern self-registration: already exists, activating")
        activate()

      {:error, reason} ->
        Logger.warning("Lantern self-registration failed: #{inspect(reason)}")
        :ok
    end
  end

  defp activate do
    case Manager.activate(@lantern_name) do
      {:ok, _project} ->
        Logger.info("Lantern self-registration: activated (lantern#{Application.get_env(:lantern, :tld, ".glow")})")
        :ok

      {:error, reason} ->
        Logger.warning("Lantern self-registration: activation failed: #{inspect(reason)}")
        :ok
    end
  end

  defp api_endpoints do
    [
      %{method: "GET", path: "/", description: "API discovery document"},
      %{method: "GET", path: "/api/projects", description: "List all projects"},
      %{method: "POST", path: "/api/projects", description: "Register a new project"},
      %{method: "POST", path: "/api/projects/scan", description: "Scan workspace for projects"},
      %{method: "GET", path: "/api/projects/:name", description: "Get project details"},
      %{method: "PUT", path: "/api/projects/:name", description: "Update project"},
      %{method: "PATCH", path: "/api/projects/:name", description: "Patch project fields"},
      %{method: "DELETE", path: "/api/projects/:name", description: "Remove project"},
      %{method: "POST", path: "/api/projects/:name/activate", description: "Activate a project"},
      %{method: "POST", path: "/api/projects/:name/deactivate", description: "Deactivate a project"},
      %{method: "POST", path: "/api/projects/:name/restart", description: "Restart a project"},
      %{method: "GET", path: "/api/tools", description: "List registered tools"},
      %{method: "GET", path: "/api/tools/:id", description: "Get tool details"},
      %{method: "GET", path: "/api/tools/:id/docs", description: "Get tool documentation"},
      %{method: "GET", path: "/api/health", description: "Project health overview"},
      %{method: "GET", path: "/api/system/health", description: "System health status"},
      %{method: "POST", path: "/api/system/init", description: "Initialize system (DNS, TLS, Caddy)"},
      %{method: "GET", path: "/api/system/settings", description: "Get settings"},
      %{method: "PUT", path: "/api/system/settings", description: "Update settings"},
      %{method: "GET", path: "/api/services", description: "List infrastructure services"},
      %{method: "GET", path: "/api/templates", description: "List project templates"},
      %{method: "GET", path: "/api/profiles", description: "List profiles"},
      %{method: "GET", path: "/api/ports", description: "List allocated ports"},
      %{method: "GET", path: "/api/dependencies", description: "List project dependencies"},
      %{method: "POST", path: "/mcp", description: "MCP (Model Context Protocol) endpoint"}
    ]
  end
end
