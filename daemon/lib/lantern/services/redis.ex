defmodule Lantern.Services.Redis do
  @moduledoc """
  Manages the Redis service.
  Default port: 6379
  """

  @behaviour Lantern.Services.Service

  alias Lantern.System.Systemd

  @unit_name "redis-server.service"
  @port 6379

  def service_info do
    %Lantern.Services.Service{
      name: "redis",
      module: __MODULE__,
      ports: %{default: @port}
    }
  end

  @impl true
  def start, do: Systemd.start(@unit_name)

  @impl true
  def stop, do: Systemd.stop(@unit_name)

  @impl true
  def status do
    case Systemd.status(@unit_name) do
      {:ok, status} -> status
      _ -> :stopped
    end
  end

  @impl true
  def health_check do
    case :gen_tcp.connect(~c"127.0.0.1", @port, [:binary], 2000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, _} ->
        {:error, :unhealthy}
    end
  end
end
