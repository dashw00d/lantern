defmodule Lantern.Config.Store do
  @moduledoc """
  GenServer for persisting application state to a JSON file.
  Stores active projects, port assignments, service states, etc.
  Uses atomic writes (temp file + rename) for safety.
  """

  use GenServer

  @default_state %{
    projects: %{},
    port_assignments: %{},
    service_states: %{}
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def get(key) when is_atom(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put(key, value) when is_atom(key) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def update_in_key(key, sub_key, value) do
    GenServer.call(__MODULE__, {:update_in_key, key, sub_key, value})
  end

  def delete_in_key(key, sub_key) do
    GenServer.call(__MODULE__, {:delete_in_key, key, sub_key})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state_dir =
      Keyword.get(opts, :state_dir) ||
        Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))

    state_path = Path.join(state_dir, "state.json")
    data = load_from_file(state_path)

    {:ok, %{data: data, path: state_path}}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.data, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state.data, key), state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    new_data = Map.put(state.data, key, value)
    save_to_file(new_data, state.path)
    {:reply, :ok, %{state | data: new_data}}
  end

  @impl true
  def handle_call({:update_in_key, key, sub_key, value}, _from, state) do
    current = Map.get(state.data, key, %{})
    updated = Map.put(current, sub_key, value)
    new_data = Map.put(state.data, key, updated)
    save_to_file(new_data, state.path)
    {:reply, :ok, %{state | data: new_data}}
  end

  @impl true
  def handle_call({:delete_in_key, key, sub_key}, _from, state) do
    current = Map.get(state.data, key, %{})
    updated = Map.delete(current, sub_key)
    new_data = Map.put(state.data, key, updated)
    save_to_file(new_data, state.path)
    {:reply, :ok, %{state | data: new_data}}
  end

  # Private helpers

  defp load_from_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, data} when is_map(data) ->
            Map.merge(@default_state, data)

          _ ->
            @default_state
        end

      {:error, _} ->
        @default_state
    end
  end

  defp save_to_file(data, path) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    tmp_path = path <> ".tmp"

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write!(tmp_path, json)
        File.rename!(tmp_path, path)

      {:error, _} ->
        :ok
    end
  end
end
