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
    PortAllocator,
    ProjectSupervisor,
    ProcessRunner
  }

  alias Lantern.System.Caddy
  alias Lantern.Config.{Settings, Store}

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
    GenServer.call(__MODULE__, {:activate, name}, 15_000)
  end

  @doc """
  Deactivates a project: stops dev server, removes Caddy config.
  """
  def deactivate(name) do
    GenServer.call(__MODULE__, {:deactivate, name}, 15_000)
  end

  @doc """
  Restarts a project's dev server.
  """
  def restart(name) do
    GenServer.call(__MODULE__, {:restart, name}, 15_000)
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
    workspace_roots = configured_workspace_roots()

    discovered_projects =
      Enum.reduce(paths, %{}, fn path, acc ->
        name = Path.basename(path)

        case Map.get(state.projects, name) do
          nil ->
            # New project - detect it
            project = Detector.detect(path)
            Map.put(acc, name, project)

          existing ->
            # Keep existing project data, update path if it moved
            updated = if existing.path != path, do: %{existing | path: path}, else: existing
            Map.put(acc, name, updated)
        end
      end)

    preserved_projects =
      preserve_registered_projects(state.projects, discovered_projects, workspace_roots)

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
  def handle_call({:register, attrs}, _from, state) do
    with {:ok, name} <- validate_register_attrs(attrs),
         nil <- Map.get(state.projects, name) do
      project = Project.new(attrs)

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

      with :ok <- ensure_caddy_config(project),
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
    run_cmd = project.run_cmd |> to_string() |> String.trim()

    if run_cmd == "" do
      :ok
    else
      start_project_runner(project)
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
    Caddy.remove_config(project.name)
    Caddy.reload()
    PortAllocator.release(project.name)

    %{project | status: :stopped, pid: nil, port: nil}
  end

  defp do_deactivate(%Project{} = project) do
    stop_project_runner(project.name)
    Caddy.remove_config(project.name)
    Caddy.reload()
    %{project | status: :stopped, pid: nil}
  end

  defp maybe_release_port(%Project{type: :proxy, name: name}), do: PortAllocator.release(name)
  defp maybe_release_port(_project), do: :ok

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
    :depends_on,
    :routing
  ]

  defp apply_project_updates(%Project{} = project, attrs) do
    updates =
      attrs
      |> Map.take(@updatable_fields)
      |> normalize_project_updates(project)

    updated = struct(project, updates)

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

  defp maybe_deactivate_for_rename(updated_project, _current_project, _current_name, _target_name),
    do: updated_project

  defp apply_name_change(%Project{} = project, current_name, target_name)
       when current_name != target_name do
    tld = Application.get_env(:lantern, :tld, ".glow")
    default_domain = current_name <> tld
    next_domain = if project.domain == default_domain, do: target_name <> tld, else: project.domain
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

  defp ensure_name_available(target_name, current_name, _projects) when target_name == current_name,
    do: :ok

  defp ensure_name_available(target_name, _current_name, projects) do
    if Map.has_key?(projects, target_name) do
      {:error, :already_exists}
    else
      :ok
    end
  end

  defp configured_workspace_roots do
    case Settings.get(:workspace_roots) do
      roots when is_list(roots) and roots != [] -> Enum.map(roots, &Path.expand/1)
      _ -> [Path.expand("~/sites")]
    end
  end

  defp preserve_registered_projects(existing_projects, discovered_projects, workspace_roots) do
    Enum.reduce(existing_projects, %{}, fn {name, project}, acc ->
      case project do
        %Project{} ->
          cond do
            Map.has_key?(discovered_projects, name) ->
              acc

            not persistent_project?(project) ->
              acc

            project_in_workspace_roots?(project.path, workspace_roots) ->
              acc

            true ->
              Map.put(acc, name, project)
          end

        _ ->
          acc
      end
    end)
  end

  defp project_in_workspace_roots?(path, workspace_roots) when is_binary(path) do
    expanded_path = Path.expand(path)

    Enum.any?(workspace_roots, fn root ->
      expanded_root = Path.expand(root)
      expanded_path == expanded_root or String.starts_with?(expanded_path, expanded_root <> "/")
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
