defmodule LanternWeb.ServiceController do
  use LanternWeb, :controller

  alias Lantern.System.Systemd

  @known_services %{
    "mailpit" => %{
      name: "mailpit",
      unit: "mailpit.service",
      ports: %{smtp: 1025, ui: 8025},
      ui_url: "http://127.0.0.1:8025"
    },
    "redis" => %{
      name: "redis",
      unit: "redis-server.service",
      ports: %{default: 6379},
      ui_url: nil
    },
    "postgres" => %{
      name: "postgres",
      unit: "postgresql.service",
      ports: %{default: 5432},
      ui_url: nil
    }
  }

  def index(conn, _params) do
    services =
      Enum.map(@known_services, fn {name, info} ->
        status = get_service_status(info.unit)

        %{
          name: name,
          status: status,
          ports: info.ports,
          ui_url: info.ui_url,
          health_check_url: info.ui_url
        }
      end)

    json(conn, %{data: services})
  end

  def status(conn, %{"name" => name}) do
    case Map.get(@known_services, name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Service '#{name}' not found"})

      info ->
        status = get_service_status(info.unit)
        json(conn, %{data: %{name: name, status: status, ports: info.ports, ui_url: info.ui_url}})
    end
  end

  def start(conn, %{"name" => name}) do
    case Map.get(@known_services, name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Service '#{name}' not found"})

      info ->
        case Systemd.start(info.unit) do
          :ok ->
            broadcast_service_change(name, :running)

            json(conn, %{
              data: %{name: name, status: :running, ports: info.ports, ui_url: info.ui_url}
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "start_failed", message: reason})
        end
    end
  end

  def stop(conn, %{"name" => name}) do
    case Map.get(@known_services, name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Service '#{name}' not found"})

      info ->
        case Systemd.stop(info.unit) do
          :ok ->
            broadcast_service_change(name, :stopped)

            json(conn, %{
              data: %{name: name, status: :stopped, ports: info.ports, ui_url: info.ui_url}
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "stop_failed", message: reason})
        end
    end
  end

  defp get_service_status(unit) do
    case Systemd.status(unit) do
      {:ok, status} -> status
      _ -> :unknown
    end
  end

  defp broadcast_service_change(name, status) do
    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "services:lobby",
      {:service_change, name, status}
    )
  rescue
    _ -> :ok
  end
end
