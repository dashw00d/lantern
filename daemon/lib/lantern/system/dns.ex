defmodule Lantern.System.DNS do
  @moduledoc """
  Manages DNS resolution for .test domains via dnsmasq/NetworkManager.
  """

  @dnsmasq_conf "/etc/NetworkManager/dnsmasq.d/lantern.conf"

  @doc """
  Returns the dnsmasq config content for wildcard .test resolution.
  """
  def dnsmasq_config(tld \\ ".test") do
    # Strip leading dot if present
    tld = String.trim_leading(tld, ".")
    "address=/.#{tld}/127.0.0.1\n"
  end

  @doc """
  Writes the dnsmasq configuration and restarts NetworkManager.
  """
  def setup(tld \\ ".test") do
    config = dnsmasq_config(tld)

    with :ok <- write_config(config),
         :ok <- restart_network_manager() do
      :ok
    end
  end

  @doc """
  Verifies that .test domains resolve to 127.0.0.1.
  """
  def verify(domain \\ "test-verify.test") do
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

  # Private helpers

  defp write_config(content) do
    tmp_path = Path.join(System.tmp_dir!(), "lantern_dns_#{:rand.uniform(100_000)}")
    File.write!(tmp_path, content)

    case System.cmd("pkexec", ["cp", tmp_path, @dnsmasq_conf], stderr_to_stdout: true) do
      {_, 0} ->
        File.rm(tmp_path)
        :ok

      {output, _} ->
        File.rm(tmp_path)
        {:error, "Failed to write DNS config: #{String.trim(output)}"}
    end
  rescue
    e -> {:error, "Failed to write DNS config: #{inspect(e)}"}
  end

  defp restart_network_manager do
    case System.cmd("pkexec", ["systemctl", "restart", "NetworkManager"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Failed to restart NetworkManager: #{String.trim(output)}"}
    end
  rescue
    e -> {:error, "Failed to restart NetworkManager: #{inspect(e)}"}
  end
end
