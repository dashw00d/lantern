defmodule Lantern.System.DNS do
  @moduledoc """
  Manages DNS resolution for .glow domains via dnsmasq/NetworkManager.
  """

  alias Lantern.System.Privilege

  @dnsmasq_conf "/etc/NetworkManager/dnsmasq.d/lantern.conf"

  @doc """
  Returns the dnsmasq config content for wildcard .glow resolution.
  """
  def dnsmasq_config(tld \\ ".glow") do
    # Strip leading dot if present
    tld = String.trim_leading(tld, ".")
    "address=/.#{tld}/127.0.0.1\n"
  end

  @doc """
  Writes the dnsmasq configuration and restarts NetworkManager.
  """
  def setup(tld \\ ".glow") do
    config = dnsmasq_config(tld)

    with :ok <- Privilege.sudo_write(@dnsmasq_conf, config),
         :ok <- Privilege.sudo("systemctl", ["restart", "NetworkManager"]) do
      :ok
    end
  end

  @doc """
  Verifies that .glow domains resolve to 127.0.0.1.
  """
  def verify(domain \\ "test-verify.glow") do
    case System.cmd("dig", ["+short", domain, "@127.0.0.1"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(String.trim(output), "127.0.0.1") do
          :ok
        else
          {:error, "DNS resolution returned: #{String.trim(output)}"}
        end

      {output, _} ->
        {:error, "dig command failed: #{String.trim(output)}"}
    end
  rescue
    _ -> {:error, "dig command not available"}
  end

  @doc """
  Checks if dnsmasq is available on the system.
  """
  def dnsmasq_available? do
    case System.cmd("which", ["dnsmasq"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if NetworkManager is using dnsmasq.
  """
  def network_manager_dnsmasq? do
    case File.read("/etc/NetworkManager/NetworkManager.conf") do
      {:ok, content} -> String.contains?(content, "dns=dnsmasq")
      _ -> false
    end
  end

  @doc """
  Returns the current DNS setup status.
  """
  def status do
    %{
      dnsmasq_available: dnsmasq_available?(),
      config_exists: File.exists?(@dnsmasq_conf),
      network_manager_dnsmasq: network_manager_dnsmasq?()
    }
  end
end
