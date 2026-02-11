defmodule Lantern.Projects.PortAllocator do
  @moduledoc """
  GenServer that assigns unique ports to projects from a configured range.
  Checks port availability and persists assignments via the state store.
  """

  use GenServer

  alias Lantern.Config.Store

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Allocates a port for the given project name.
  Returns an existing assignment if one exists, otherwise assigns a new port.
  """
  def allocate(project_name) do
    GenServer.call(__MODULE__, {:allocate, project_name})
  end

  @doc """
  Releases a port assignment for the given project name.
  """
  def release(project_name) do
    GenServer.call(__MODULE__, {:release, project_name})
  end

  @doc """
  Returns the current port assignment for a project, or nil.
  """
  def get(project_name) do
    GenServer.call(__MODULE__, {:get, project_name})
  end

  @doc """
  Returns all current port assignments as a map of {project_name => port}.
  """
  def assignments do
    GenServer.call(__MODULE__, :assignments)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    range_start = Application.get_env(:lantern, :port_range_start, 41000)
    range_end = Application.get_env(:lantern, :port_range_end, 42000)

    # Load existing assignments from store
    existing = load_assignments()

    state = %{
      assignments: existing,
      range_start: range_start,
      range_end: range_end
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:allocate, project_name}, _from, state) do
    case Map.get(state.assignments, project_name) do
      nil ->
        case find_available_port(state) do
          {:ok, port} ->
            new_assignments = Map.put(state.assignments, project_name, port)
            persist_assignments(new_assignments)
            {:reply, {:ok, port}, %{state | assignments: new_assignments}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      existing_port ->
        {:reply, {:ok, existing_port}, state}
    end
  end

  @impl true
  def handle_call({:release, project_name}, _from, state) do
    new_assignments = Map.delete(state.assignments, project_name)
    persist_assignments(new_assignments)
    {:reply, :ok, %{state | assignments: new_assignments}}
  end

  @impl true
  def handle_call({:get, project_name}, _from, state) do
    {:reply, Map.get(state.assignments, project_name), state}
  end

  @impl true
  def handle_call(:assignments, _from, state) do
    {:reply, state.assignments, state}
  end

  # Private helpers

  defp find_available_port(state) do
    used_ports = MapSet.new(Map.values(state.assignments))

    result =
      state.range_start..state.range_end
      |> Enum.find(fn port ->
        not MapSet.member?(used_ports, port) and port_available?(port)
      end)

    case result do
      nil -> {:error, :no_ports_available}
      port -> {:ok, port}
    end
  end

  defp port_available?(port) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  defp load_assignments do
    case Store.get(:port_assignments) do
      assignments when is_map(assignments) ->
        Map.new(assignments, fn {k, v} -> {to_string(k), v} end)

      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp persist_assignments(assignments) do
    Store.put(:port_assignments, assignments)
  rescue
    _ -> :ok
  end
end
