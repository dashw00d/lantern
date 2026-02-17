defmodule Lantern.Health.Checker do
  @moduledoc """
  GenServer that periodically health-checks projects with configured
  base_url + health_endpoint. Uses Finch for HTTP requests.
  """

  use GenServer

  require Logger

  alias Lantern.Projects.Manager
  alias Lantern.Config.Store

  @default_interval 60_000
  @check_timeout 5_000
  @max_concurrency 10
  @history_size 10

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns health status for all tracked projects."
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc "Returns health status for a single project."
  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc "Triggers an immediate health check for a project."
  def check_now(name) do
    GenServer.call(__MODULE__, {:check_now, name}, @check_timeout + 5_000)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    results = load_results()
    schedule_check(interval)
    {:ok, %{results: results, interval: interval}}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, state.results, state}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.results, name), state}
  end

  @impl true
  def handle_call({:check_now, name}, _from, state) do
    projects = Manager.list()

    case Enum.find(projects, fn p -> p.name == name end) do
      nil ->
        {:reply, {:error, :not_found}, state}

      project ->
        if checkable?(project) do
          result = perform_check(project)
          new_results = update_result(state.results, name, result)
          persist_results(new_results)
          broadcast_results(new_results)
          {:reply, {:ok, Map.get(new_results, name)}, %{state | results: new_results}}
        else
          {:reply, {:error, :not_found}, state}
        end
    end
  end

  @impl true
  def handle_info(:check, state) do
    projects = Manager.list()

    checkable =
      projects
      |> Enum.filter(&checkable?/1)

    # Prune stale results for projects that no longer exist
    known_names = MapSet.new(projects, & &1.name)
    pruned_results = Map.filter(state.results, fn {name, _} -> MapSet.member?(known_names, name) end)

    new_results =
      checkable
      |> Task.async_stream(
        fn project ->
          {project.name, perform_check(project)}
        end,
        max_concurrency: @max_concurrency,
        timeout: @check_timeout + 1_000,
        on_timeout: :kill_task
      )
      |> Enum.reduce(pruned_results, fn
        {:ok, {name, result}}, acc ->
          update_result(acc, name, result)

        {:exit, _reason}, acc ->
          acc
      end)

    persist_results(new_results)
    broadcast_results(new_results)
    schedule_check(state.interval)
    {:noreply, %{state | results: new_results}}
  end

  # Private helpers

  defp checkable?(%{health_endpoint: endpoint, enabled: enabled} = project)
       when is_binary(endpoint) and enabled == true do
    is_binary(check_base_url(project))
  end

  defp checkable?(_), do: false

  defp check_base_url(%{base_url: base_url}) when is_binary(base_url), do: base_url
  defp check_base_url(%{upstream_url: upstream_url}) when is_binary(upstream_url), do: upstream_url
  defp check_base_url(_), do: nil

  defp perform_check(project) do
    base = check_base_url(project)
    url = String.trim_trailing(base, "/") <> project.health_endpoint
    start_time = System.monotonic_time(:millisecond)

    try do
      request = Finch.build(:get, url)

      case Finch.request(request, Lantern.Finch, receive_timeout: @check_timeout) do
        {:ok, %{status: status}} when status in 200..299 ->
          latency = System.monotonic_time(:millisecond) - start_time
          %{status: "healthy", latency_ms: latency, error: nil}

        {:ok, %{status: status}} ->
          latency = System.monotonic_time(:millisecond) - start_time
          %{status: "unhealthy", latency_ms: latency, error: "HTTP #{status}"}

        {:error, reason} ->
          latency = System.monotonic_time(:millisecond) - start_time
          %{status: "unreachable", latency_ms: latency, error: friendly_error(reason)}
      end
    rescue
      e ->
        latency = System.monotonic_time(:millisecond) - start_time
        %{status: "error", latency_ms: latency, error: Exception.message(e)}
    end
  end

  defp friendly_error(%{reason: :econnrefused}), do: "connection refused"
  defp friendly_error(%{reason: :timeout}), do: "connection timed out"
  defp friendly_error(%{reason: :closed}), do: "connection closed"
  defp friendly_error(%{reason: :nxdomain}), do: "DNS lookup failed"
  defp friendly_error(%{reason: reason}) when is_atom(reason), do: Atom.to_string(reason)
  defp friendly_error(reason), do: inspect(reason)

  defp update_result(results, name, check_result) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    existing = Map.get(results, name, %{history: []})
    history = [Map.put(check_result, :checked_at, now) | Map.get(existing, :history, [])]
    history = Enum.take(history, @history_size)

    Map.put(results, name, %{
      status: check_result.status,
      latency_ms: check_result.latency_ms,
      checked_at: now,
      error: check_result.error,
      history: history
    })
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end

  defp broadcast_results(results) do
    Phoenix.PubSub.broadcast(Lantern.PubSub, "health:updates", {:health_update, results})
  rescue
    _ -> :ok
  end

  defp load_results do
    case Store.get(:health_results) do
      results when is_map(results) -> normalize_result_keys(results)
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp normalize_result_keys(results) when is_map(results) do
    Map.new(results, fn {key, value} ->
      {to_string(key), value}
    end)
  end

  defp persist_results(results) do
    Store.put(:health_results, results)
  rescue
    _ -> :ok
  end
end
