defmodule Lantern.System.Systemd do
  @moduledoc """
  Wrapper around systemctl commands for managing system services.
  Uses sudo for privilege escalation (configured via sudoers.d/lantern).
  """

  alias Lantern.System.Privilege

  def start(service_name), do: Privilege.sudo("systemctl", ["start", service_name])
  def stop(service_name), do: Privilege.sudo("systemctl", ["stop", service_name])
  def restart(service_name), do: Privilege.sudo("systemctl", ["restart", service_name])
  def reload(service_name), do: Privilege.sudo("systemctl", ["reload", service_name])

  @doc """
  Gets the status of a systemd service.
  Does not need sudo — is-active is unprivileged.
  """
  def status(service_name) do
    case System.cmd("systemctl", ["is-active", service_name], stderr_to_stdout: true) do
      {"active\n", 0} -> {:ok, :running}
      {"inactive\n", _} -> {:ok, :stopped}
      {"failed\n", _} -> {:ok, :failed}
      {output, _} -> {:error, String.trim(output)}
    end
  rescue
    _ -> {:error, "systemctl not available"}
  end

  @doc """
  Checks if a service is enabled (starts on boot).
  Does not need sudo.
  """
  def enabled?(service_name) do
    case System.cmd("systemctl", ["is-enabled", service_name], stderr_to_stdout: true) do
      {"enabled\n", 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  def enable(service_name), do: Privilege.sudo("systemctl", ["enable", service_name])
  def disable(service_name), do: Privilege.sudo("systemctl", ["disable", service_name])

  @doc """
  Installs a systemd unit file via staging + sudo cp.
  """
  def install_unit(unit_name, content) do
    unit_path = "/etc/systemd/system/#{unit_name}"

    with :ok <- Privilege.sudo_write(unit_path, content),
         :ok <- Privilege.sudo("systemctl", ["daemon-reload"]) do
      :ok
    end
  end

  @doc """
  Removes a systemd unit file.
  """
  def remove_unit(unit_name) do
    unit_path = "/etc/systemd/system/#{unit_name}"

    with :ok <- Privilege.sudo("rm", ["-f", unit_path]),
         :ok <- Privilege.sudo("systemctl", ["daemon-reload"]) do
      :ok
    end
  end
end
