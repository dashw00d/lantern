defmodule Lantern.Projects.DiscoveryWorker do
  @moduledoc """
  Periodically refreshes docs/API discovery metadata.
  """

  use GenServer

  require Logger

  alias Lantern.Projects.Manager

  @default_interval_ms :timer.minutes(10)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    interval_ms = Application.get_env(:lantern, :discovery_interval_ms, @default_interval_ms)
    Process.send_after(self(), :refresh_discovery, 2_000)
    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:refresh_discovery, state) do
    _ = safe_refresh_discovery()
    Process.send_after(self(), :refresh_discovery, state.interval_ms)
    {:noreply, state}
  end

  defp safe_refresh_discovery do
    Manager.refresh_discovery(:all)
  rescue
    error ->
      Logger.warning("Discovery refresh failed: #{Exception.message(error)}")
      :error
  catch
    :exit, {:timeout, _} = reason ->
      Logger.warning("Discovery refresh timed out: #{inspect(reason)}")
      :timeout

    :exit, reason ->
      Logger.warning("Discovery refresh exited: #{inspect(reason)}")
      :error
  end
end
