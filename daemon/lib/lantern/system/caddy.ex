defmodule Lantern.System.Caddy do
  @moduledoc """
  Manages Caddy web server configuration for project routing.
  Generates per-project .caddy config files and reloads Caddy.
  """

  alias Lantern.Projects.Project

  @sites_dir "/etc/caddy/sites.d"
  @caddyfile_path "/etc/caddy/Caddyfile"

  @doc """
  Returns the base Caddyfile content that imports site configs.
  """
  def base_caddyfile do
    """
    {
      local_certs
    }
    import #{@sites_dir}/*.caddy
    """
  end

  @doc """
  Generates the Caddy config content for a project.
  """
  def generate_config(%Project{type: :php} = project) do
    socket = Application.get_env(:lantern, :php_fpm_socket, "/run/php/php8.3-fpm.sock")
    root = project.root || "public"
    root_path = Path.join(project.path, root)

    """
    #{project.domain} {
      root * #{root_path}
      php_fastcgi unix/#{socket}
      file_server
    }
    """
  end

  def generate_config(%Project{type: :proxy} = project) do
    port = project.port || raise "Proxy project #{project.name} has no assigned port"

    base = """
    #{project.domain} {
      reverse_proxy 127.0.0.1:#{port}
    }
    """

    base
  end

  def generate_config(%Project{type: :static} = project) do
    root = project.root || "."
    root_path = Path.join(project.path, root)

    """
    #{project.domain} {
      root * #{root_path}
      file_server
    }
    """
  end

  def generate_config(%Project{type: type}) do
    {:error, "Cannot generate Caddy config for project type: #{type}"}
  end

  @doc """
  Generates a Caddy config with WebSocket support for proxy projects.
  """
  def generate_config_with_websocket(%Project{type: :proxy} = project) do
    port = project.port || raise "Proxy project #{project.name} has no assigned port"

    """
    #{project.domain} {
      reverse_proxy 127.0.0.1:#{port} {
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
      }
    }
    """
  end

  @doc """
  Returns the file path for a project's Caddy config.
  """
  def config_path(project_name) do
    Path.join(@sites_dir, "#{project_name}.caddy")
  end

  @doc """
  Writes a project's Caddy config file. Requires elevated privileges.
  Returns :ok or {:error, reason}.
  """
  def write_config(%Project{} = project) do
    config = generate_config(project)

    case config do
      {:error, reason} ->
        {:error, reason}

      content ->
        path = config_path(project.name)
        run_privileged("mkdir", ["-p", @sites_dir])
        run_privileged_write(path, content)
    end
  end

  @doc """
  Removes a project's Caddy config file.
  """
  def remove_config(project_name) do
    path = config_path(project_name)
    run_privileged("rm", ["-f", path])
  end

  @doc """
  Reloads the Caddy service to apply config changes.
  """
  def reload do
    run_privileged("systemctl", ["reload", "caddy"])
  end

  @doc """
  Writes the base Caddyfile if it doesn't exist.
  """
  def ensure_base_config do
    run_privileged("mkdir", ["-p", @sites_dir])

    case File.exists?(@caddyfile_path) do
      true -> :ok
      false -> run_privileged_write(@caddyfile_path, base_caddyfile())
    end
  end

  @doc """
  Checks if Caddy is installed on the system.
  """
  def installed? do
    case System.cmd("which", ["caddy"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  # Private helpers

  defp run_privileged(cmd, args) do
    System.cmd("pkexec", [cmd | args], stderr_to_stdout: true)
  rescue
    _ -> {:error, "Failed to run privileged command: #{cmd}"}
  end

  defp run_privileged_write(path, content) do
    # Write via tee with pkexec
    tmp_path = Path.join(System.tmp_dir!(), "lantern_caddy_#{:rand.uniform(100_000)}")
    File.write!(tmp_path, content)

    case System.cmd("pkexec", ["cp", tmp_path, path], stderr_to_stdout: true) do
      {_, 0} ->
        File.rm(tmp_path)
        :ok

      {output, _} ->
        File.rm(tmp_path)
        {:error, "Failed to write #{path}: #{output}"}
    end
  rescue
    e -> {:error, "Failed to write #{path}: #{inspect(e)}"}
  end
end
