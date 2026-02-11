defmodule Lantern.Services.Postgres do
  @moduledoc """
  Manages the PostgreSQL service.
  Default port: 5432
  """

  @behaviour Lantern.Services.Service

  alias Lantern.System.Systemd

  @unit_name "postgresql.service"
  @port 5432

  def service_info do
    %Lantern.Services.Service{
      name: "postgres",
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
