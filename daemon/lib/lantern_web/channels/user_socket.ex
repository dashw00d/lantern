defmodule LanternWeb.UserSocket do
  use Phoenix.Socket

  channel "project:*", LanternWeb.ProjectChannel
  channel "services:*", LanternWeb.ServiceChannel
  channel "system:*", LanternWeb.HealthChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
