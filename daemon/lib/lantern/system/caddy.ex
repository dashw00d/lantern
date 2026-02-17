defmodule Lantern.System.Caddy do
  @moduledoc """
  Manages Caddy web server configuration for project routing.
  Generates per-project .caddy config files and reloads Caddy.

  Config files in /etc/caddy/sites.d/ are written directly (directory
  is owned by the daemon user after init). Service management uses
  sudo via the Privilege module.
  """

  alias Lantern.Projects.Project
  alias Lantern.System.Privilege

  require Logger

  @sites_dir "/etc/caddy/sites.d"
  @caddyfile_path "/etc/caddy/Caddyfile"
  @lighthouse_config_file "__lantern_lighthouse.caddy"
  @reload_timeout_ms 30_000
  @restart_timeout_ms 30_000

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
  def generate_config(%Project{upstream_url: upstream_url} = project)
      when is_binary(upstream_url) do
    upstream = String.trim(upstream_url)

    if upstream == "" do
      generate_config(%{project | upstream_url: nil})
    else
      """
      #{project.domain} {
        reverse_proxy #{upstream}
      }
      """
    end
  end

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

    """
    #{project.domain} {
      reverse_proxy 127.0.0.1:#{port}
    }
    """
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

  defp lighthouse_config_path do
    Path.join(@sites_dir, @lighthouse_config_file)
  end

  @doc """
  Writes a project's Caddy config file.
  sites.d is owned by the daemon user, so no privilege escalation needed.
  """
  def write_config(%Project{} = project) do
    config = generate_config(project)

    case config do
      {:error, reason} ->
        {:error, reason}

      content ->
        with :ok <- ensure_lighthouse_config() do
          path = config_path(project.name)

          case File.write(path, content) do
            :ok ->
              :ok

            {:error, :enoent} ->
              {:error,
               "#{@sites_dir} does not exist. Run 'lantern init' or reinstall the package."}

            {:error, :eacces} ->
              {:error,
               "Permission denied writing to #{@sites_dir}. Run 'lantern init' to fix ownership."}

            {:error, reason} ->
              {:error, "Failed to write config: #{inspect(reason)}"}
          end
        end
    end
  end

  @doc """
  Removes a project's Caddy config file.
  """
  def remove_config(project_name) do
    path = config_path(project_name)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, "Failed to remove #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  Reloads the Caddy service to apply config changes.
  """
  def reload do
    case Privilege.sudo("systemctl", ["reload", "caddy"], timeout: @reload_timeout_ms) do
      :ok ->
        :ok

      {:error, reload_reason} ->
        Logger.warning("[Caddy] reload failed, attempting restart: #{reload_reason}")

        case Privilege.sudo("systemctl", ["restart", "caddy"], timeout: @restart_timeout_ms) do
          :ok ->
            :ok

          {:error, restart_reason} ->
            {:error, "reload failed: #{reload_reason}; restart failed: #{restart_reason}"}
        end
    end
  end

  @doc """
  Writes the base Caddyfile and creates sites.d with user ownership.
  Called during `lantern init`. Uses sudo for privileged paths.
  """
  def ensure_base_config do
    user = System.get_env("USER", "root")

    # Create sites.d and recursively assign ownership so upgrades from
    # root-owned configs become writable by the daemon user.
    with :ok <- Privilege.sudo("mkdir", ["-p", @sites_dir]),
         :ok <- Privilege.sudo("chown", ["-R", user, @sites_dir]) do
      # Write base Caddyfile if it doesn't have our import
      needs_write =
        case File.read(@caddyfile_path) do
          {:ok, content} -> not String.contains?(content, "import #{@sites_dir}")
          {:error, _} -> true
        end

      if needs_write do
        Privilege.sudo_write(@caddyfile_path, base_caddyfile())
      else
        :ok
      end
      |> case do
        :ok -> ensure_lighthouse_config()
        other -> other
      end
    end
  end

  @doc """
  Ensures the lighthouse docs host is configured.
  """
  def ensure_lighthouse_config do
    case File.write(lighthouse_config_path(), lighthouse_config()) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write lighthouse config: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "Failed to write lighthouse config: #{Exception.message(e)}"}
  end

  defp lighthouse_config do
    port =
      Application.get_env(:lantern, LanternWeb.Endpoint, [])
      |> Keyword.get(:http, [])
      |> Keyword.get(:port, 4777)

    """
    #{lighthouse_domain()} {
      reverse_proxy 127.0.0.1:#{port}
    }
    """
  end

  defp lighthouse_domain do
    "lighthouse" <> Application.get_env(:lantern, :tld, ".glow")
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

  @doc """
  Checks if the Caddy systemd service exists.
  """
  def service_exists? do
    case System.cmd("systemctl", ["cat", "caddy"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
