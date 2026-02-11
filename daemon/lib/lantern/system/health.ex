defmodule Lantern.System.Health do
  @moduledoc """
  Builds normalized system health payloads for HTTP and websocket clients.
  """

  alias Lantern.System.{Caddy, DNS, TLS}

  def status do
    %{
      dns: dns_component(),
      caddy: caddy_component(),
      tls: tls_component(),
      daemon: daemon_component()
    }
  end

  defp dns_component do
    dns = DNS.status()

    cond do
      dns.dnsmasq_available and dns.network_manager_dnsmasq and dns.config_exists ->
        %{status: :ok, message: "dnsmasq is configured for local domains"}

      dns.dnsmasq_available ->
        %{status: :warning, message: "dnsmasq is available but DNS setup is incomplete"}

      true ->
        %{status: :error, message: "dnsmasq is not installed"}
    end
  end

  defp caddy_component do
    if Caddy.installed?() do
      %{status: :ok, message: "Caddy is installed"}
    else
      %{status: :error, message: "Caddy is not installed"}
    end
  end

  defp tls_component do
    tls = TLS.status()

    cond do
      tls.caddy_installed and tls.ca_trusted ->
        %{status: :ok, message: "Local TLS certificate authority is trusted"}

      tls.caddy_installed ->
        %{status: :warning, message: "Local TLS certificate authority is not trusted"}

      true ->
        %{status: :error, message: "Caddy must be installed before TLS can be trusted"}
    end
  end

  defp daemon_component do
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)

    %{
      status: :ok,
      message: "Lantern daemon is running",
      uptime: format_uptime(uptime_ms)
    }
  end

  defp format_uptime(uptime_ms) do
    total_seconds = div(uptime_ms, 1_000)
    days = div(total_seconds, 86_400)
    hours = div(rem(total_seconds, 86_400), 3_600)
    minutes = div(rem(total_seconds, 3_600), 60)
    seconds = rem(total_seconds, 60)

    units =
      [
        if(days > 0, do: "#{days}d"),
        if(hours > 0 or days > 0, do: "#{hours}h"),
        if(minutes > 0 or hours > 0 or days > 0, do: "#{minutes}m"),
        "#{seconds}s"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(units, " ")
  end
end
