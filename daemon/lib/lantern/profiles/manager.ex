defmodule Lantern.Profiles.Manager do
  @moduledoc """
  Manages configuration profiles.
  Profiles define which services are active, which projects auto-start, etc.
  """

  use GenServer

  alias Lantern.Profiles.Profile

  @builtin_profiles %{
    "light" => %Profile{
      name: "light",
      description: "Caddy + active project only",
      services: []
    },
    "full_stack" => %Profile{
      name: "full_stack",
      description: "Caddy + Redis + Postgres + Mailpit",
      services: ["redis", "postgres", "mailpit"]
    },
    "demo" => %Profile{
      name: "demo",
      description: "Fixed ports, auto-open browser, auto-start all",
      services: ["redis", "postgres", "mailpit"],
      port_range_start: 41000,
      port_range_end: 41100
    }
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def active do
    GenServer.call(__MODULE__, :active)
  end

  def activate(name) do
    GenServer.call(__MODULE__, {:activate, name})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    profiles = Map.merge(@builtin_profiles, load_user_profiles())
    active_name = load_active_profile()

    {:ok, %{profiles: profiles, active: active_name}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.profiles), state}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.profiles, name), state}
  end

  @impl true
  def handle_call(:active, _from, state) do
    profile = Map.get(state.profiles, state.active)
    {:reply, profile, state}
  end

  @impl true
  def handle_call({:activate, name}, _from, state) do
    case Map.get(state.profiles, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      profile ->
        save_active_profile(name)
        {:reply, {:ok, profile}, %{state | active: name}}
    end
  end

  # Private helpers

  defp load_user_profiles do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    profiles_dir = Path.join(state_dir, "profiles")

    case File.ls(profiles_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.reduce(%{}, fn file, acc ->
          path = Path.join(profiles_dir, file)

          case File.read(path) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, data} ->
                  profile = %Profile{
                    name: data["name"],
                    description: data["description"],
                    services: data["services"] || [],
                    auto_start_projects: data["auto_start_projects"] || [],
                    env: data["env"] || %{}
                  }

                  Map.put(acc, profile.name, profile)

                _ ->
                  acc
              end

            _ ->
              acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp load_active_profile do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    path = Path.join(state_dir, "active_profile")

    case File.read(path) do
      {:ok, name} -> String.trim(name)
      _ -> "light"
    end
  end

  defp save_active_profile(name) do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    File.mkdir_p!(state_dir)
    File.write!(Path.join(state_dir, "active_profile"), name)
  rescue
    _ -> :ok
  end
end
