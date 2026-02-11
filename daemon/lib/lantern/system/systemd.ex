defmodule Lantern.System.Systemd do
  @moduledoc """
  Wrapper around systemctl commands for managing system services.
  Uses pkexec for privilege escalation when needed.
  """

  @doc """
  Starts a systemd service.
  """
  def start(service_name) do
    run_systemctl("start", service_name)
  end

  @doc """
  Stops a systemd service.
  """
  def stop(service_name) do
    run_systemctl("stop", service_name)
  end

  @doc """
  Restarts a systemd service.
  """
  def restart(service_name) do
    run_systemctl("restart", service_name)
  end

  @doc """
  Reloads a systemd service configuration.
  """
  def reload(service_name) do
    run_systemctl("reload", service_name)
  end

  @doc """
  Gets the status of a systemd service.
  Returns {:ok, :running | :stopped | :failed} or {:error, reason}.
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
  """
  def enabled?(service_name) do
    case System.cmd("systemctl", ["is-enabled", service_name], stderr_to_stdout: true) do
      {"enabled\n", 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Enables a service to start on boot.
  """
  def enable(service_name) do
    run_privileged("systemctl", ["enable", service_name])
  end

  @doc """
  Disables a service from starting on boot.
  """
  def disable(service_name) do
    run_privileged("systemctl", ["disable", service_name])
  end

  @doc """
  Installs a systemd unit file.
  """
  def install_unit(unit_name, content) do
    unit_path = "/etc/systemd/system/#{unit_name}"
    tmp_path = Path.join(System.tmp_dir!(), "lantern_unit_#{:rand.uniform(100_000)}")
    File.write!(tmp_path, content)

    with {_, 0} <- System.cmd("pkexec", ["cp", tmp_path, unit_path], stderr_to_stdout: true),
         {_, 0} <- System.cmd("pkexec", ["systemctl", "daemon-reload"], stderr_to_stdout: true) do
      File.rm(tmp_path)
      :ok
    else
      {output, _} ->
        File.rm(tmp_path)
        {:error, "Failed to install unit: #{String.trim(output)}"}
    end
  rescue
    e -> {:error, "Failed to install unit: #{inspect(e)}"}
  end

  @doc """
  Removes a systemd unit file.
  """
  def remove_unit(unit_name) do
    unit_path = "/etc/systemd/system/#{unit_name}"

    with {_, 0} <- System.cmd("pkexec", ["rm", "-f", unit_path], stderr_to_stdout: true),
         {_, 0} <- System.cmd("pkexec", ["systemctl", "daemon-reload"], stderr_to_stdout: true) do
      :ok
    else
      {output, _} -> {:error, "Failed to remove unit: #{String.trim(output)}"}
    end
  rescue
    e -> {:error, "Failed to remove unit: #{inspect(e)}"}
  end

  # Private helpers

  defp run_systemctl(action, service_name) do
    run_privileged("systemctl", [action, service_name])
  end

  defp run_privileged(cmd, args) do
    case System.cmd("pkexec", [cmd | args], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, "#{cmd} #{Enum.join(args, " ")} failed: #{String.trim(output)}"}
    end
  rescue
    e -> {:error, "Failed to run #{cmd}: #{inspect(e)}"}
  end
end
