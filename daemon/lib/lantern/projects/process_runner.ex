defmodule Lantern.Projects.ProcessRunner do
  @moduledoc """
  GenServer that manages a single running dev server process.
  Captures output, handles restarts, and broadcasts log lines.
  """

  use GenServer, restart: :temporary

  require Logger

  alias Lantern.Projects.Project

  @max_log_lines 1000
  @max_retries 5
  @base_backoff_ms 1000
  @shutdown_timeout_ms 5000

  defstruct [
    :project,
    :port_ref,
    :os_pid,
    log_buffer: :queue.new(),
    log_count: 0,
    retry_count: 0,
    status: :starting
  ]

  # Client API

  def start_link(%Project{} = project) do
    GenServer.start_link(__MODULE__, project, name: via(project.name))
  end

  def get_logs(project_name) do
    GenServer.call(via(project_name), :get_logs)
  end

  def get_status(project_name) do
    GenServer.call(via(project_name), :get_status)
  end

  def stop_server(project_name) do
    GenServer.call(via(project_name), :stop_server)
  end

  # Server callbacks

  @impl true
  def init(%Project{} = project) do
    state = %__MODULE__{project: project}
    {:ok, state, {:continue, :start_process}}
  end

  @impl true
  def handle_continue(:start_process, state) do
    case start_os_process(state.project) do
      {:ok, port_ref, os_pid} ->
        broadcast_status(state.project.name, :starting)

        new_state = %{state | port_ref: port_ref, os_pid: os_pid, status: :running}
        broadcast_status(state.project.name, :running)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to start #{state.project.name}: #{inspect(reason)}")
        broadcast_status(state.project.name, :error)
        {:noreply, %{state | status: :error}}
    end
  end

  @impl true
  def handle_call(:get_logs, _from, state) do
    logs = :queue.to_list(state.log_buffer)
    {:reply, logs, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:stop_server, _from, state) do
    new_state = do_stop(state)
    {:stop, :normal, :ok, new_state}
  end

  @impl true
  def handle_info({port_ref, {:data, data}}, %{port_ref: port_ref} = state) do
    line = to_string(data)
    new_state = append_log(state, line)
    broadcast_log(state.project.name, line)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({port_ref, {:exit_status, exit_code}}, %{port_ref: port_ref} = state) do
    Logger.info("Process #{state.project.name} exited with code #{exit_code}")

    if state.status == :running and state.retry_count < @max_retries do
      backoff = (@base_backoff_ms * :math.pow(2, state.retry_count)) |> round()

      Logger.info(
        "Retrying #{state.project.name} in #{backoff}ms (attempt #{state.retry_count + 1}/#{@max_retries})"
      )

      Process.send_after(self(), :retry, backoff)

      {:noreply,
       %{
         state
         | status: :starting,
           retry_count: state.retry_count + 1,
           port_ref: nil,
           os_pid: nil
       }}
    else
      broadcast_status(state.project.name, :error)
      {:noreply, %{state | status: :error, port_ref: nil, os_pid: nil}}
    end
  end

  @impl true
  def handle_info(:retry, state) do
    {:noreply, state, {:continue, :start_process}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_stop(state)
    :ok
  end

  # Private helpers

  defp start_os_process(%Project{} = project) do
    cmd = Project.interpolate_cmd(project.run_cmd, project)

    if cmd == nil or cmd == "" do
      {:error, :no_run_cmd}
    else
      cwd = resolve_cwd(project)
      env = build_env(project)
      {spawn_cmd, spawn_args} = spawn_program_and_args(cmd)

      try do
        port =
          Port.open({:spawn_executable, spawn_cmd}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:cd, cwd},
            {:env, env},
            {:args, spawn_args}
          ])

        # Get the OS PID from the port info
        info = Port.info(port)
        os_pid = Keyword.get(info || [], :os_pid)

        {:ok, port, os_pid}
      rescue
        e -> {:error, e}
      end
    end
  end

  defp resolve_cwd(%Project{path: path, run_cwd: nil}), do: path
  defp resolve_cwd(%Project{path: path, run_cwd: "."}), do: path
  defp resolve_cwd(%Project{path: path, run_cwd: cwd}), do: Path.join(path, cwd)

  defp build_env(%Project{run_env: run_env, port: port, domain: domain, name: name}) do
    base = %{
      "PORT" => to_string(port || ""),
      "DOMAIN" => domain || "",
      "PROJECT_NAME" => name
    }

    Map.merge(base, run_env || %{})
    |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
  end

  defp do_stop(%{os_pid: nil, port_ref: port_ref} = state) do
    safe_close_port(port_ref)
    %{state | status: :stopped, port_ref: nil}
  end

  defp do_stop(%{os_pid: os_pid, port_ref: port_ref} = state) do
    # Stop the spawned process and wait for exit.
    _ = System.cmd("kill", ["-TERM", to_string(os_pid)], stderr_to_stdout: true)

    # Wait for graceful shutdown
    receive do
      {^port_ref, {:exit_status, _}} -> :ok
    after
      @shutdown_timeout_ms ->
        # Force kill process.
        _ = System.cmd("kill", ["-KILL", to_string(os_pid)], stderr_to_stdout: true)
    end

    safe_close_port(port_ref)
    broadcast_status(state.project.name, :stopped)
    %{state | status: :stopped, port_ref: nil, os_pid: nil}
  rescue
    _ -> %{state | status: :stopped, port_ref: nil, os_pid: nil}
  end

  defp append_log(state, line) do
    new_buffer = :queue.in(line, state.log_buffer)
    new_count = state.log_count + 1

    if new_count > @max_log_lines do
      {_, trimmed} = :queue.out(new_buffer)
      %{state | log_buffer: trimmed, log_count: @max_log_lines}
    else
      %{state | log_buffer: new_buffer, log_count: new_count}
    end
  end

  defp broadcast_status(project_name, status) do
    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:#{project_name}",
      {:status_change, project_name, status}
    )

    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:lobby",
      {:status_change, project_name, status}
    )
  end

  defp broadcast_log(project_name, line) do
    Phoenix.PubSub.broadcast(
      Lantern.PubSub,
      "project:#{project_name}",
      {:log_line, project_name, line}
    )
  end

  defp via(project_name) do
    {:via, Registry, {Lantern.ProcessRegistry, {:runner, project_name}}}
  end

  defp spawn_program_and_args(cmd) do
    {~c"/bin/sh", ["-lc", cmd]}
  end

  defp safe_close_port(nil), do: :ok

  defp safe_close_port(port_ref) do
    Port.close(port_ref)
  rescue
    _ -> :ok
  end
end
