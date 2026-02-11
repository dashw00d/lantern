defmodule LanternWeb.ServiceChannel do
  @moduledoc """
  Channel for service status updates.
  Topic: "services:lobby"
  """

  use Phoenix.Channel

  @impl true
  def join("services:lobby", _payload, socket) do
    Phoenix.PubSub.subscribe(Lantern.PubSub, "services:lobby")
    {:ok, %{}, socket}
  end

  @impl true
  def handle_info({:service_change, name, status}, socket) do
    push(socket, "service_updated", %{service: %{name: name, status: status}})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
