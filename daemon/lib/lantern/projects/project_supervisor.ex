defmodule Lantern.Projects.ProjectSupervisor do
  @moduledoc """
  DynamicSupervisor for process runners.
  Each running project gets its own ProcessRunner child.
  """

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_runner(project) do
    spec = {Lantern.Projects.ProcessRunner, project}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_runner(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
