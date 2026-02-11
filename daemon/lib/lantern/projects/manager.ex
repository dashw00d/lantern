defmodule Lantern.Projects.Manager do
  @moduledoc """
  GenServer managing all project state.
  Provides scan, activate, deactivate, and query operations.
  """

  use GenServer

  require Logger

  alias Lantern.Projects.{Project, Scanner, Detector, PortAllocator, ProjectSupervisor, ProcessRunner}
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
  Returns a single project by name.
  """
  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc """
  Returns all projects.
  """
  def list do
    GenServer.call(__MODULE__, :list)
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

    new_projects =
      Enum.reduce(paths, state.projects, fn path, acc ->
        name = Path.basename(path)

        case Map.get(acc, name) do
          nil ->
            # New project - detect it
            project = Detector.detect(path)
            Map.put(acc, name, project)

          existing ->
            # Keep existing project, update path if needed
            if existing.path != path do
              Map.put(acc, name, %{existing | path: path})
            else
              acc
            end
        end
      end)

    persist_projects(new_projects)
    {:reply, {:ok, Map.values(new_projects)}, %{state | projects: new_projects}}
  end

  @impl true
  def handle_call({:activate, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        case do_activate(project) do
          {:ok, updated_project} ->
            new_projects = Map.put(state.projects, name, updated_project)
            persist_projects(new_projects)
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
        {:reply, {:ok, updated_project}, %{state | projects: new_projects}}
    end
  end

  @impl true
  def handle_call({:restart, name}, _from, state) do
    case Map.get(state.projects, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        do_deactivate(project)

        case do_activate(project) do
          {:ok, updated_project} ->
            new_projects = Map.put(state.projects, name, updated_project)
            persist_projects(new_projects)
            {:reply, {:ok, updated_project}, %{state | projects: new_projects}}

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
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.projects), state}
  end

  # Private helpers

  defp do_activate(%Project{type: :proxy} = project) do
    with {:ok, port} <- PortAllocator.allocate(project.name) do
      project = %{project | port: port, status: :starting}

      # Generate and write Caddy config
      Caddy.write_config(project)
      Caddy.reload()

      # Start the dev server process
      case ProjectSupervisor.start_runner(project) do
        {:ok, _pid} ->
          {:ok, %{project | status: :running}}

        {:error, reason} ->
          Logger.error("Failed to start runner for #{project.name}: #{inspect(reason)}")
          {:ok, %{project | status: :error}}
      end
    end
  end

  defp do_activate(%Project{type: type} = project) when type in [:php, :static] do
    project = %{project | status: :running}
    Caddy.write_config(project)
    Caddy.reload()
    {:ok, project}
  end

  defp do_activate(%Project{type: :unknown} = project) do
    {:error, "Cannot activate project #{project.name}: unknown type, needs configuration"}
  end

  defp do_activate(_project) do
    {:error, "Cannot activate project with unsupported type"}
  end

  defp do_deactivate(%Project{type: :proxy, status: status} = project)
       when status in [:running, :starting] do
    # Stop the process runner
    try do
      ProcessRunner.stop_server(project.name)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end

    # Remove Caddy config
    Caddy.remove_config(project.name)
    Caddy.reload()

    %{project | status: :stopped, pid: nil}
  end

  defp do_deactivate(%Project{} = project) do
    Caddy.remove_config(project.name)
    Caddy.reload()
    %{project | status: :stopped, pid: nil}
  end

  defp load_projects do
    case Store.get(:projects) do
      projects when is_map(projects) ->
        Map.new(projects, fn {name, data} ->
          key = to_string(name)
          project = if is_struct(data, Project), do: data, else: Project.from_map(data)
          {key, %{project | status: :stopped, pid: nil}}
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
end
