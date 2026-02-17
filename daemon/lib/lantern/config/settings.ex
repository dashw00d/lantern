defmodule Lantern.Config.Settings do
  @moduledoc """
  GenServer managing global Lantern settings.
  Loads from ~/.config/lantern/settings.json on boot.
  """

  use GenServer

  @default_settings %{
    workspace_roots: [],
    tld: ".glow",
    php_fpm_socket: "/run/php/php8.3-fpm.sock",
    caddy_mode: "files",
    state_dir: nil,
    port_range_start: 41000,
    port_range_end: 42000
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

  def update(attrs) when is_map(attrs) do
    GenServer.call(__MODULE__, {:update, attrs})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state_dir =
      Keyword.get(opts, :state_dir) ||
        Application.get_env(:lantern, :state_dir, default_state_dir())

    settings_path = Path.join(state_dir, "settings.json")

    settings =
      @default_settings
      |> Map.put(:state_dir, state_dir)
      |> Map.put(
        :workspace_roots,
        Application.get_env(:lantern, :workspace_roots, [Path.expand("~/sites")])
      )
      |> Map.put(:tld, Application.get_env(:lantern, :tld, ".glow"))
      |> merge_from_file(settings_path)

    {:ok, %{settings: settings, path: settings_path}}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.settings, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state.settings, key), state}
  end

  @allowed_update_keys ~w(workspace_roots tld php_fpm_socket caddy_mode default_template active_profile)a

  @impl true
  def handle_call({:update, attrs}, _from, state) do
    filtered =
      attrs
      |> atomize_keys()
      |> Map.take(@allowed_update_keys)

    new_settings = Map.merge(state.settings, filtered)
    save_to_file(new_settings, state.path)
    {:reply, :ok, %{state | settings: new_settings}}
  end

  # Private helpers

  defp default_state_dir do
    Path.expand("~/.config/lantern")
  end

  defp merge_from_file(settings, path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} when is_map(data) ->
            Map.merge(settings, atomize_keys(data))

          _ ->
            settings
        end

      {:error, _} ->
        settings
    end
  end

  defp save_to_file(settings, path) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    tmp_path = path <> ".tmp"

    case Jason.encode(settings, pretty: true) do
      {:ok, json} ->
        File.write!(tmp_path, json)
        File.rename!(tmp_path, path)

      {:error, _} ->
        :ok
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        try do
          Map.put(acc, String.to_existing_atom(key), value)
        rescue
          ArgumentError -> acc
        end

      _, acc ->
        acc
    end)
  end

  defp atomize_keys(_), do: %{}
end
