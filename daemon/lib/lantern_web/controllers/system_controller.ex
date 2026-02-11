defmodule LanternWeb.SystemController do
  use LanternWeb, :controller

  alias Lantern.System.Health
  alias Lantern.System.{Caddy, DNS, TLS}
  alias Lantern.Config.Settings

  def health(conn, _params) do
    json(conn, %{data: Health.status()})
  end

  def init(conn, _params) do
    results = %{
      dns: run_init_step(:dns, fn -> DNS.setup() end),
      tls: run_init_step(:tls, fn -> TLS.trust() end),
      caddy: run_init_step(:caddy, fn -> Caddy.ensure_base_config() end)
    }

    status = if Enum.all?(Map.values(results), &(&1 == :ok)), do: :ok, else: :partial

    json(conn, %{data: %{status: status, results: results}})
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

  defp run_init_step(_name, fun) do
    case fun.() do
      :ok -> :ok
      {:error, reason} -> %{error: reason}
      other -> other
    end
  rescue
    e -> %{error: inspect(e)}
  end
end
