defmodule Lantern.Services.Mailpit do
  @moduledoc """
  Manages the Mailpit email testing service.
  SMTP: 127.0.0.1:1025, UI: http://127.0.0.1:8025
  """

  @behaviour Lantern.Services.Service

  alias Lantern.System.Systemd

  @unit_name "mailpit.service"
  @smtp_port 1025
  @ui_port 8025
  @ui_url "http://127.0.0.1:#{@ui_port}"

  @unit_content """
  [Unit]
  Description=Mailpit - Email Testing Tool
  After=network.target

  [Service]
  Type=simple
  ExecStart=/usr/local/bin/mailpit
  Restart=on-failure
  User=nobody

  [Install]
  WantedBy=multi-user.target
  """

  def service_info do
    %Lantern.Services.Service{
      name: "mailpit",
      module: __MODULE__,
      ports: %{smtp: @smtp_port, ui: @ui_port},
      health_check_url: @ui_url
    }
  end

  @impl true
  def start do
    ensure_unit_installed()
    Systemd.start(@unit_name)
  end

  @impl true
  def stop do
    Systemd.stop(@unit_name)
  end

  @impl true
  def status do
    case Systemd.status(@unit_name) do
      {:ok, status} -> status
      _ -> :stopped
    end
  end

  @impl true
  def health_check do
    case :httpc.request(:get, {~c"#{@ui_url}", []}, [timeout: 2000], []) do
      {:ok, {{_, 200, _}, _, _}} -> :ok
      _ -> {:error, :unhealthy}
    end
  rescue
    _ -> {:error, :unhealthy}
  end

  defp ensure_unit_installed do
    case Systemd.status(@unit_name) do
      {:error, _} ->
        # Unit likely not installed
        Systemd.install_unit(@unit_name, @unit_content)

      _ ->
        :ok
    end
  end
end
