defmodule Lantern.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LanternWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:lantern, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lantern.PubSub},
      {Registry, keys: :unique, name: Lantern.ProcessRegistry},
      Lantern.Config.Settings,
      Lantern.Config.Store,
      Lantern.Projects.PortAllocator,
      Lantern.Projects.ProjectSupervisor,
      Lantern.Projects.Manager,
      Lantern.Templates.Registry,
      Lantern.Profiles.Manager,
      {Finch, name: Lantern.Finch},
      Lantern.Health.Checker,
      Hermes.Server.Registry,
      {Lantern.MCP.Server, transport: :streamable_http},
      # Start to serve requests, typically the last entry
      LanternWeb.Endpoint
    ] ++ self_registration_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lantern.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp self_registration_children do
    if Application.get_env(:lantern, :self_register, true) do
      [{Task, fn -> Lantern.SelfRegistration.register() end}]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LanternWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
