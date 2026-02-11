defmodule Lantern.System.TLS do
  @moduledoc """
  Manages TLS certificate trust for local HTTPS via Caddy's internal CA.
  """

  alias Lantern.System.Privilege

  @doc """
  Runs `caddy trust` to install the local CA certificate.
  """
  def trust do
    Privilege.sudo("caddy", ["trust"])
  end

  @doc """
  Verifies that the Caddy local CA is trusted.
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
    Lantern.System.Caddy.installed?()
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
