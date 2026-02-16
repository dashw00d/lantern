defmodule LanternWeb.SystemController do
  use LanternWeb, :controller

  alias Lantern.System.Health
  alias Lantern.System.{Caddy, DNS, TLS}
  alias Lantern.Config.Settings
  alias Lantern.Projects.Manager
  alias Lantern.System.Systemd

  @managed_service_units ["mailpit.service", "redis-server.service", "postgresql.service"]

  def health(conn, _params) do
    json(conn, %{data: Health.status()})
  end

  def init(conn, _params) do
    if Caddy.installed?() do
      results = %{
        dns: run_init_step(:dns, fn -> DNS.setup() end),
        tls: run_init_step(:tls, fn -> TLS.trust() end),
        caddy: run_init_step(:caddy, fn -> Caddy.ensure_base_config() end)
      }

      status = if Enum.all?(Map.values(results), &(&1 == :ok)), do: :ok, else: :partial

      json(conn, %{data: %{status: status, results: results}})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error: "caddy_not_installed",
        message:
          "Caddy is not installed. Install it first:\n" <>
            "  sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl\n" <>
            "  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg\n" <>
            "  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list\n" <>
            "  sudo apt update && sudo apt install caddy"
      })
    end
  end

  def show_settings(conn, _params) do
    settings = Settings.get()
    json(conn, %{data: settings})
  end

  def update_settings(conn, params) do
    Settings.update(params)
    settings = Settings.get()
    json(conn, %{data: settings})
  end

  def shutdown(conn, _params) do
    projects_result =
      case Manager.deactivate_all() do
        {:ok, projects} -> %{status: :ok, stopped_projects: Enum.map(projects, & &1.name)}
        {:error, reason} -> %{status: :error, error: inspect(reason)}
      end

    services_result =
      if Application.get_env(:lantern, :shutdown_stop_services, true) do
        @managed_service_units
        |> Enum.map(fn unit -> {unit, stop_service_unit(unit)} end)
        |> Map.new()
      else
        %{}
      end

    overall_status =
      if projects_result.status == :ok and Enum.all?(services_result, fn {_k, v} -> v == :ok end) do
        :ok
      else
        :partial
      end

    json(conn, %{
      data: %{
        status: overall_status,
        projects: projects_result,
        services: services_result
      }
    })
  end

  defp run_init_step(_name, fun) do
    case fun.() do
      :ok -> :ok
      {:error, reason} -> %{error: reason}
      other -> other
    end
  rescue
    e -> %{error: inspect(e)}
  end

  defp stop_service_unit(unit) do
    case Systemd.stop(unit) do
      :ok -> :ok
      {:error, reason} -> %{error: reason}
    end
  end
end
