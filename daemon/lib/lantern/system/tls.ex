defmodule Lantern.System.TLS do
  @moduledoc """
  Manages TLS certificate trust for local HTTPS via Caddy's internal CA.
  """

  @doc """
  Runs `caddy trust` to install the local CA certificate.
  Requires elevated privileges.
  """
  def trust do
    case System.cmd("pkexec", ["caddy", "trust"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Failed to trust Caddy CA: #{String.trim(output)}"}
    end
  rescue
    _ -> {:error, "caddy trust command not available"}
  end

  @doc """
  Verifies that the Caddy local CA is trusted.
  Checks by looking for the Caddy CA cert in system trust stores.
  """
  def trusted? do
    caddy_data_dir = System.get_env("XDG_DATA_HOME", Path.expand("~/.local/share"))
    ca_cert = Path.join([caddy_data_dir, "caddy", "pki", "authorities", "local", "root.crt"])

    File.exists?(ca_cert)
  end

  @doc """
  Checks if Caddy is installed on the system.
  """
  def caddy_installed? do
    case System.cmd("which", ["caddy"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Returns the current TLS setup status.
  """
  def status do
    %{
      caddy_installed: caddy_installed?(),
      ca_trusted: trusted?()
    }
  end
end
