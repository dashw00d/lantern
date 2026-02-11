defmodule LanternWeb.HealthChannel do
  @moduledoc """
  Channel for periodic system health broadcasts.
  Topic: "system:health"
  """

  use Phoenix.Channel

  alias Lantern.System.Health

  @health_interval_ms 30_000

  @impl true
  def join("system:health", _payload, socket) do
    # Send initial health status
    health = get_health()
    send(self(), :broadcast_health)
    {:ok, %{health: health}, socket}
  end

  @impl true
  def handle_info(:broadcast_health, socket) do
    health = get_health()
    push(socket, "health_update", %{health: health})
    Process.send_after(self(), :broadcast_health, @health_interval_ms)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp get_health do
    Health.status()
  end
end
