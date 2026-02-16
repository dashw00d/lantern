defmodule Lantern.Projects.Manager do
  @moduledoc """
  GenServer managing all project state.
  Provides scan, activate, deactivate, and query operations.
  """

  use GenServer

  require Logger

  alias Lantern.Projects.{
    Project,
    Scanner,
    Detector,
    Discovery,
    DeployRunner,
    PortAllocator,
    ProjectSupervisor,
    ProcessRunner
  }

  alias Lantern.System.Caddy
  alias Lantern.Config.Store

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Scans workspace directories and detects project types.
  """
  def scan do
    GenServer.call(__MODULE__, :scan, 30_000)
  end

  @doc """
  Activates a project: generates Caddy config, starts dev server if needed.
  """
  def activate(name) do
    GenServer.call(__MODULE__, {:activate, name}, 30_000)
  end

  @doc """
  Deactivates a project: stops dev server, removes Caddy config.
  """
  def deactivate(name) do
    GenServer.call(__MODULE__, {:deactivate, name}, 30_000)
  end

  @doc """
  Deactivates all running projects.
  """
  def deactivate_all do
    GenServer.call(__MODULE__, :deactivate_all, 30_000)
  end

  @doc """
  Restarts a project's dev server.
  """
  def restart(name) do
    GenServer.call(__MODULE__, {:restart, name}, 30_000)
  end

  @doc """
  Updates persisted project configuration fields.
  """
  def update(name, attrs) when is_map(attrs) do
    GenServer.call(__MODULE__, {:update, name, attrs}, 15_000)
  end

  @doc """
  Returns a single project by name.
  """
  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc """
  Returns a single project by ID, falling back to name lookup.
  """
  def get_by_id(id) do
    GenServer.call(__MODULE__, {:get_by_id, id})
  end

  @doc """
  Returns all projects.
  """
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Refreshes discovery metadata for one project or all projects.
  """
  def refresh_discovery(name \\ :all) do
    GenServer.call(__MODULE__, {:refresh_discovery, name}, 30_000)
  end

  @doc """
  Resets a project's persisted configuration from its local manifest file.
  Does not write back to the manifest.
  """
  def reset_from_manifest(name) do
    GenServer.call(__MODULE__, {:reset_from_manifest, name}, 15_000)
  end

  @doc """
  Registers a new project from API input.
  """
  def register(attrs) when is_map(attrs) do
    GenServer.call(__MODULE__, {:register, attrs}, 15_000)
  end

  @doc """
  Deregisters (removes) a project by name.
  """
  def deregister(name) do
    GenServer.call(__MODULE__, {:deregister, name}, 15_000)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Load persisted projects from store
    projects = load_projects()
    {:ok, %{projects: projects}}
  end

  @impl true
  def handle_call(:scan, _from, state) do
    paths = Scanner.scan()

    discovered_projects =
      Enum.reduce(paths, %{}, fn path, acc ->
        name = Path.basename(path)

        case Map.get(state.projects, name) do
          nil ->
            # New project - detect it
            project = path |> Detector.detect() |> Discovery.enrich()
            Map.put(acc, name, project)

          existing ->
            # Keep existing project data, update path if it moved
            updated =
              existing
              |> then(fn project ->
                if project.path != path, do: %{project | path: path}, else: project
              end)
              |> Discovery.enrich()

            Map.put(acc, name, updated)
        end
      end)

    preserved_projects = preserve_registered_projects(state.projects, discovered_projects)

    new_projects = Map.merge(discovered_projects, preserved_projects)

    persist_projects(new_projects)
    broadcast_projects_changed(new_projects)
    {:reply, {:ok, Map.values(new_projects)}, %{state | projects: new_projects}}
  end

  @impl true
  def handle_call({:activate, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %Project{enabled: false} ->
        {:reply, {:error, :disabled}, state}

      project ->
        case do_activate(project) do
          {:ok, updated_project} ->
            new_projects = Map.put(state.projects, name, updated_project)
            persist_projects(new_projects)
            broadcast_project_updated(updated_project)
            broadcast_projects_changed(new_projects)
            {:reply, {:ok, updated_project}, %{state | projects: new_projects}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:deactivate, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        updated_project = do_deactivate(project)
        new_projects = Map.put(state.projects, name, updated_project)
        persist_projects(new_projects)
        broadcast_project_updated(updated_project)
        broadcast_projects_changed(new_projects)
        {:reply, {:ok, updated_project}, %{state | projects: new_projects}}
    end
  end

  @impl true
  def handle_call(:deactivate_all, _from, state) do
    {new_projects, changed_projects} =
      Enum.reduce(state.projects, {%{}, []}, fn {name, project}, {acc, changed} ->
        next_project =
          if project.status in [:running, :starting, :stopping, :error] do
            do_deactivate(project)
          else
            project
          end

        next_changed = if next_project == project, do: changed, else: [next_project | changed]
        {Map.put(acc, name, next_project), next_changed}
      end)

    persist_projects(new_projects)
    Enum.each(changed_projects, &broadcast_project_updated/1)
    broadcast_projects_changed(new_projects)
    {:reply, {:ok, Map.values(new_projects)}, %{state | projects: new_projects}}
  end

  @impl true
  def handle_call({:restart, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %Project{enabled: false} ->
        {:reply, {:error, :disabled}, state}

      project ->
        do_deactivate(project)

        case do_activate(project) do
          {:ok, updated_project} ->
            new_projects = Map.put(state.projects, name, updated_project)
            persist_projects(new_projects)
            broadcast_project_updated(updated_project)
            broadcast_projects_changed(new_projects)
            {:reply, {:ok, updated_project}, %{state | projects: new_projects}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:update, name, attrs}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        {requested_name, update_attrs} = Map.pop(attrs, :new_name)

        with {:ok, target_name} <- normalize_target_name(requested_name, name),
             :ok <- ensure_name_available(target_name, name, state.projects),
             {:ok, updated_project} <- apply_project_updates(project, update_attrs) do
          final_project =
            updated_project
            |> maybe_deactivate_for_visibility(project)
            |> maybe_deactivate_for_rename(project, name, target_name)
            |> apply_name_change(name, target_name)

          new_projects =
            state.projects
            |> Map.delete(name)
            |> Map.put(target_name, final_project)

          persist_projects(new_projects)
          broadcast_project_updated(final_project)
          broadcast_projects_changed(new_projects)
          {:reply, {:ok, final_project}, %{state | projects: new_projects}}
        else
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.projects, name), state}
  end

  @impl true
  def handle_call({:get_by_id, id}, _from, state) do
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn p -> p.id == id end)
      |> case do
        nil -> Map.get(state.projects, id)
        found -> found
      end

    {:reply, project, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.projects), state}
  end

  @impl true
  def handle_call({:refresh_discovery, :all}, _from, state) do
    refreshed =
      state.projects
      |> Enum.map(fn {name, project} -> {name, Discovery.enrich(project)} end)
      |> Map.new()

    persist_projects(refreshed)
    broadcast_projects_changed(refreshed)
    {:reply, {:ok, Map.values(refreshed)}, %{state | projects: refreshed}}
  end

  @impl true
  def handle_call({:refresh_discovery, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        refreshed_project = Discovery.enrich(project)
        new_projects = Map.put(state.projects, name, refreshed_project)
        persist_projects(new_projects)
        broadcast_project_updated(refreshed_project)
        broadcast_projects_changed(new_projects)
        {:reply, {:ok, refreshed_project}, %{state | projects: new_projects}}
    end
  end

  @impl true
  def handle_call({:register, attrs}, _from, state) do
    with {:ok, name} <- validate_register_attrs(attrs),
         nil <- Map.get(state.projects, name) do
      project = attrs |> Project.new() |> Discovery.enrich()

      case Project.validate(project) do
        {:ok, valid_project} ->
          new_projects = Map.put(state.projects, name, valid_project)
          persist_projects(new_projects)
          broadcast_project_updated(valid_project)
          broadcast_projects_changed(new_projects)
          {:reply, {:ok, valid_project}, %{state | projects: new_projects}}

        {:error, reasons} ->
          {:reply, {:error, {:validation, reasons}}, state}
      end
    else
      %Project{} ->
        {:reply, {:error, :already_exists}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reset_from_manifest, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %Project{} = current_project ->
        case Detector.detect_from_manifest(current_project.path, current_project.name) do
          {:ok, manifest_project} ->
            reset_project =
              manifest_project
              |> preserve_runtime_fields(current_project)
              |> Discovery.enrich()

            case Project.validate(reset_project) do
              {:ok, valid_project} ->
                new_projects = Map.put(state.projects, name, valid_project)
                persist_projects(new_projects)
                broadcast_project_updated(valid_project)
                broadcast_projects_changed(new_projects)
                {:reply, {:ok, valid_project}, %{state | projects: new_projects}}

              {:error, reasons} ->
                {:reply, {:error, {:validation, reasons}}, state}
            end

          {:error, :manifest_not_found} ->
            {:reply, {:error, :manifest_not_found}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:deregister, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        if project.status == :running, do: do_deactivate(project)
        new_projects = Map.delete(state.projects, name)
        persist_projects(new_projects)
        broadcast_projects_changed(new_projects)
        {:reply, :ok, %{state | projects: new_projects}}
    end
  end

  # Private helpers

  defp validate_register_attrs(%{name: name, path: path})
       when is_binary(name) and is_binary(path),
       do: {:ok, name}

  defp validate_register_attrs(_), do: {:error, "name and path are required"}

  defp do_activate(%Project{upstream_url: upstream_url} = project) when is_binary(upstream_url) do
    if String.trim(upstream_url) == "" do
      do_activate(%{project | upstream_url: nil})
    else
      project = %{project | status: :running}

      with :ok <- ensure_caddy_config(project),
           :ok <- maybe_start_managed_command(project) do
        {:ok, project}
      else
        {:error, reason} ->
          cleanup_activation(project)
          {:error, reason}
      end
    end
  end

  defp do_activate(%Project{type: :proxy} = project) do
    with {:ok, port} <- PortAllocator.allocate(project.name) do
      project = %{project | port: port, status: :starting}
      project = maybe_compute_base_url(project)

      with :ok <- validate_runtime_port_strategy(project),
           :ok <- ensure_caddy_config(project),
           :ok <- maybe_start_managed_command(project) do
        {:ok, %{project | status: :running}}
      else
        {:error, reason} ->
          cleanup_activation(project)
          {:error, reason}
      end
    end
  end

  defp do_activate(%Project{type: :unknown, run_cmd: run_cmd} = project)
       when is_binary(run_cmd) and byte_size(run_cmd) > 0 do
    # Unknown + run command behaves like a proxy project.
    do_activate(%{project | type: :proxy})
  end

  defp do_activate(%Project{type: type} = project) when type in [:php, :static] do
    project = %{project | status: :running}

    with :ok <- ensure_caddy_config(project),
         :ok <- maybe_start_managed_command(project) do
      {:ok, project}
    else
      {:error, reason} ->
        cleanup_activation(project)
        {:error, reason}
    end
  end

  defp do_activate(%Project{type: :unknown} = project) do
    {:error, "Cannot activate project #{project.name}: unknown type, needs configuration"}
  end

  defp do_activate(_project) do
    {:error, "Cannot activate project with unsupported type"}
  end

  defp ensure_caddy_config(project) do
    with :ok <- normalize_caddy_result(Caddy.write_config(project), "write Caddy config"),
         :ok <- normalize_caddy_result(Caddy.reload(), "reload Caddy") do
      :ok
    end
  end

  defp normalize_caddy_result(:ok, _action), do: :ok
  defp normalize_caddy_result({_, 0}, _action), do: :ok

  defp normalize_caddy_result({:error, reason}, action) do
    {:error, "#{action} failed: #{format_reason(reason)}"}
  end

  defp normalize_caddy_result({output, exit_code}, action)
       when is_integer(exit_code) do
    rendered_output = output |> to_string() |> String.trim()
    base = "#{action} failed with exit code #{exit_code}"

    if rendered_output == "" do
      {:error, base}
    else
      {:error, "#{base}: #{rendered_output}"}
    end
  end

  defp normalize_caddy_result(other, action) do
    {:error, "#{action} failed: #{format_reason(other)}"}
  end

  defp maybe_start_managed_command(%Project{} = project) do
    if runtime_command_configured?(project, :start) do
      maybe_run_runtime_command(project, :start)
    else
      maybe_start_run_cmd(project)
    end
  end

  defp maybe_start_run_cmd(%Project{} = project) do
    run_cmd = project.run_cmd |> to_string() |> String.trim()

    if run_cmd == "" do
      :ok
    else
      with :ok <- start_project_runner(project),
           :ok <- wait_for_runtime_ready(project) do
        :ok
      end
    end
  end

  defp start_project_runner(%Project{} = project) do
    case ProjectSupervisor.start_runner(project) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        # Recover stale runner state left behind by previous lifecycle operations.
        stop_project_runner(project.name)

        case ProjectSupervisor.start_runner(project) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, "start project runner failed: #{format_reason(reason)}"}
        end

      {:error, reason} ->
        {:error, "start project runner failed: #{format_reason(reason)}"}
    end
  end

  defp cleanup_activation(%Project{} = project) do
    stop_project_runner(project.name)
    Caddy.remove_config(project.name)
    Caddy.reload()
    maybe_release_port(project)
    :ok
  end

  defp stop_project_runner(project_name) do
    try do
      ProcessRunner.stop_server(project_name)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end

    :ok
  end

  defp format_reason(reason) when is_binary(reason), do: String.trim(reason)
  defp format_reason(reason), do: inspect(reason)

  defp do_deactivate(%Project{type: :proxy} = project) do
    stop_project_runner(project.name)
    stop_listener_on_port(project.port)
    _ = maybe_run_runtime_command(project, :stop)
    Caddy.remove_config(project.name)
    Caddy.reload()
    PortAllocator.release(project.name)

    %{project | status: :stopped, pid: nil, port: nil}
  end

  defp do_deactivate(%Project{} = project) do
    stop_project_runner(project.name)
    stop_listener_on_port(project.port)
    _ = maybe_run_runtime_command(project, :stop)
    Caddy.remove_config(project.name)
    Caddy.reload()
    %{project | status: :stopped, pid: nil}
  end

  defp maybe_release_port(%Project{type: :proxy, name: name}), do: PortAllocator.release(name)
  defp maybe_release_port(_project), do: :ok

  # When base_url is not explicitly configured, derive it from the assigned port.
  # This allows tools to use ${PORT} for dynamic port assignment and have
  # service discovery return the correct URL automatically.
  defp maybe_compute_base_url(%Project{base_url: nil, port: port} = project)
       when is_integer(port) do
    %{project | base_url: "http://127.0.0.1:#{port}"}
  end

  defp maybe_compute_base_url(project), do: project

  @updatable_fields [
    :type,
    :domain,
    :path,
    :root,
    :run_cmd,
    :run_cwd,
    :run_env,
    :features,
    :template,
    :description,
    :kind,
    :base_url,
    :upstream_url,
    :health_endpoint,
    :repo_url,
    :tags,
    :enabled,
    :deploy,
    :docs,
    :endpoints,
    :docs_auto,
    :api_auto,
    :depends_on,
    :routing
  ]

  defp apply_project_updates(%Project{} = project, attrs) do
    updates =
      attrs
      |> Map.take(@updatable_fields)
      |> normalize_project_updates(project)

    updated = struct(project, updates) |> Discovery.enrich()

    case Project.validate(updated) do
      {:ok, valid_project} -> {:ok, valid_project}
      {:error, reasons} -> {:error, {:validation, reasons}}
    end
  end

  defp normalize_project_updates(attrs, project) do
    attrs
    |> Enum.reduce(%{}, fn
      {:run_cmd, nil}, acc ->
        Map.put(acc, :run_cmd, nil)

      {:run_cmd, value}, acc when is_binary(value) ->
        trimmed = String.trim(value)
        Map.put(acc, :run_cmd, if(trimmed == "", do: nil, else: trimmed))

      {:run_cwd, nil}, acc ->
        Map.put(acc, :run_cwd, ".")

      {:run_cwd, value}, acc when is_binary(value) ->
        trimmed = String.trim(value)
        Map.put(acc, :run_cwd, if(trimmed == "", do: ".", else: trimmed))

      {:run_env, nil}, acc ->
        Map.put(acc, :run_env, %{})

      {:run_env, env}, acc when is_map(env) ->
        normalized =
          Map.new(env, fn {k, v} ->
            {to_string(k), to_string(v)}
          end)

        Map.put(acc, :run_env, normalized)

      {:upstream_url, nil}, acc ->
        Map.put(acc, :upstream_url, nil)

      {:upstream_url, value}, acc when is_binary(value) ->
        trimmed = String.trim(value)
        Map.put(acc, :upstream_url, if(trimmed == "", do: nil, else: trimmed))

      {:features, nil}, acc ->
        Map.put(acc, :features, %{})

      {:features, features}, acc when is_map(features) ->
        Map.put(acc, :features, features)

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
    |> maybe_default_to_proxy(project)
  end

  defp maybe_default_to_proxy(updates, %Project{type: :unknown}) do
    cond do
      Map.has_key?(updates, :type) ->
        updates

      Map.get(updates, :run_cmd) in [nil, ""] ->
        updates

      true ->
        Map.put(updates, :type, :proxy)
    end
  end

  defp maybe_default_to_proxy(updates, _project), do: updates

  defp maybe_deactivate_for_visibility(
         %Project{enabled: false} = updated_project,
         %Project{status: :running} = current_project
       ) do
    deactivated = do_deactivate(current_project)

    %{
      updated_project
      | status: deactivated.status,
        pid: deactivated.pid,
        port: deactivated.port
    }
  end

  defp maybe_deactivate_for_visibility(updated_project, _current_project), do: updated_project

  defp maybe_deactivate_for_rename(
         %Project{status: :running} = updated_project,
         %Project{status: :running} = current_project,
         current_name,
         target_name
       )
       when current_name != target_name do
    deactivated = do_deactivate(current_project)

    %{
      updated_project
      | status: deactivated.status,
        pid: deactivated.pid,
        port: deactivated.port
    }
  end

  defp maybe_deactivate_for_rename(
         updated_project,
         _current_project,
         _current_name,
         _target_name
       ),
       do: updated_project

  defp apply_name_change(%Project{} = project, current_name, target_name)
       when current_name != target_name do
    tld = Application.get_env(:lantern, :tld, ".glow")
    default_domain = current_name <> tld

    next_domain =
      if project.domain == default_domain, do: target_name <> tld, else: project.domain

    next_id = if project.id in [nil, current_name], do: target_name, else: project.id

    %{project | name: target_name, domain: next_domain, id: next_id}
  end

  defp apply_name_change(project, _current_name, _target_name), do: project

  defp normalize_target_name(nil, current_name), do: {:ok, current_name}
  defp normalize_target_name("", current_name), do: {:ok, current_name}

  defp normalize_target_name(requested_name, _current_name) when is_binary(requested_name) do
    trimmed = String.trim(requested_name)
    if trimmed == "", do: {:error, "name must be a non-empty string"}, else: {:ok, trimmed}
  end

  defp normalize_target_name(_requested_name, _current_name),
    do: {:error, "name must be a non-empty string"}

  defp ensure_name_available(target_name, current_name, _projects)
       when target_name == current_name,
       do: :ok

  defp ensure_name_available(target_name, _current_name, projects) do
    if Map.has_key?(projects, target_name) do
      {:error, :already_exists}
    else
      :ok
    end
  end

  defp preserve_registered_projects(existing_projects, discovered_projects) do
    Enum.reduce(existing_projects, %{}, fn {name, project}, acc ->
      case project do
        %Project{} ->
          cond do
            Map.has_key?(discovered_projects, name) ->
              acc

            not persistent_project?(project) ->
              acc

            true ->
              Map.put(acc, name, project)
          end

        _ ->
          acc
      end
    end)
  end

  defp load_projects do
    case Store.get(:projects) do
      projects when is_map(projects) ->
        projects
        |> Enum.reduce(%{}, fn {name, data}, acc ->
          key = to_string(name)
          project = if is_struct(data, Project), do: data, else: Project.from_map(data)

          if persistent_project?(project) do
            Map.put(acc, key, %{project | status: :stopped, pid: nil})
          else
            Logger.info("Dropping stale project #{key}: #{project.path} no longer exists")
            acc
          end
        end)

      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp persist_projects(projects) do
    serialized =
      Map.new(projects, fn {name, project} ->
        {name, Project.to_map(project)}
      end)

    Store.put(:projects, serialized)
  rescue
    _ -> :ok
  end

  defp maybe_run_runtime_command(%Project{} = project, command)
       when command in [:start, :stop] do
    deploy = project.deploy || %{}

    case Map.get(deploy, command) do
      value when is_binary(value) and value != "" ->
        case DeployRunner.execute(project, command) do
          {:ok, _output} ->
            :ok

          {:error, %{output: output, exit_code: code}} ->
            {:error, "runtime #{command} failed (#{code}): #{output}"}

          {:error, reason} when is_binary(reason) ->
            {:error, "runtime #{command} failed: #{reason}"}

          {:error, reason} ->
            {:error, "runtime #{command} failed: #{inspect(reason)}"}
        end

      _ ->
        :ok
    end
  end

  defp runtime_command_configured?(%Project{} = project, command)
       when command in [:start, :stop] do
    deploy = project.deploy || %{}

    case Map.get(deploy, command) do
      value when is_binary(value) -> String.trim(value) != ""
      _ -> false
    end
  end

  defp wait_for_runtime_ready(%Project{} = project) do
    run_cmd = project.run_cmd |> to_string() |> String.trim()

    cond do
      project.type != :proxy ->
        :ok

      run_cmd == "" ->
        :ok

      is_integer(project.port) == false ->
        :ok

      true ->
        timeout_ms = Application.get_env(:lantern, :project_start_timeout_ms, 15_000)
        interval_ms = 150
        deadline_ms = System.monotonic_time(:millisecond) + timeout_ms
        wait_for_port(project, deadline_ms, interval_ms, timeout_ms)
    end
  end

  defp wait_for_port(%Project{} = project, deadline_ms, interval_ms, timeout_ms) do
    cond do
      tcp_port_open?(project.port) ->
        :ok

      System.monotonic_time(:millisecond) >= deadline_ms ->
        {:error,
         "runtime did not bind to 127.0.0.1:#{project.port} within #{timeout_ms}ms (start command may have failed)"}

      true ->
        status = safe_runner_status(project.name)

        if status == :error do
          {:error, "runtime process exited during startup"}
        else
          Process.sleep(interval_ms)
          wait_for_port(project, deadline_ms, interval_ms, timeout_ms)
        end
    end
  end

  defp tcp_port_open?(port) when is_integer(port) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 250) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        false
    end
  end

  defp tcp_port_open?(_), do: false

  defp stop_listener_on_port(port) when is_integer(port) and port > 0 do
    pids = listener_pids(port)

    Enum.each(pids, fn pid ->
      _ = System.cmd("kill", ["-TERM", pid], stderr_to_stdout: true)
    end)

    if pids != [] do
      Process.sleep(200)

      listener_pids(port)
      |> Enum.each(fn pid ->
        _ = System.cmd("kill", ["-KILL", pid], stderr_to_stdout: true)
      end)
    end
  rescue
    _ -> :ok
  end

  defp stop_listener_on_port(_), do: :ok

  defp listener_pids(port) do
    case System.cmd("lsof", ["-tiTCP:#{port}", "-sTCP:LISTEN"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  defp safe_runner_status(name) do
    ProcessRunner.get_status(name)
  rescue
    _ -> :unknown
  catch
    :exit, _ -> :unknown
  end

  defp validate_runtime_port_strategy(%Project{} = project) do
    run_cmd = project.run_cmd |> to_string() |> String.trim()

    cond do
      run_cmd == "" ->
        :ok

      runtime_command_configured?(project, :start) ->
        :ok

      String.contains?(run_cmd, "${PORT}") or String.contains?(run_cmd, "$PORT") ->
        :ok

      true ->
        {:error,
         "run_cmd must use ${PORT} (or configure upstream_url/deploy.start) to avoid port conflicts"}
    end
  end

  defp preserve_runtime_fields(%Project{} = next_project, %Project{} = current_project) do
    %{
      next_project
      | status: current_project.status,
        pid: current_project.pid,
        port: current_project.port,
        registered_at: current_project.registered_at
    }
  end

  defp persistent_project?(%Project{upstream_url: upstream_url}) when is_binary(upstream_url),
    do: String.trim(upstream_url) != ""

  defp persistent_project?(%Project{path: path}) when is_binary(path), do: File.dir?(path)
  defp persistent_project?(_), do: false

  defp broadcast_project_updated(%Project{} = project) do
    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:lobby",
      {:project_updated, project}
    )

    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:#{project.name}",
      {:project_updated, project}
    )
  rescue
    _ -> :ok
  end

  defp broadcast_projects_changed(projects) when is_map(projects) do
    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:lobby",
      {:projects_changed, Map.values(projects)}
    )
  rescue
    _ -> :ok
  end
end
