defmodule LanternWeb.ProjectChannel do
  @moduledoc """
  Channel for project status updates and per-project log streaming.

  Topics:
  - "project:lobby" — broadcasts all project status changes
  - "project:<name>" — per-project logs and health updates
  """

  use Phoenix.Channel

  alias Lantern.Projects.{Manager, Project, ProcessRunner}

  @impl true
  def join("project:lobby", _payload, socket) do
    # Subscribe to the PubSub lobby topic
    Phoenix.PubSub.subscribe(Lantern.PubSub, "project:lobby")
    projects = Manager.list()
    {:ok, %{projects: Enum.map(projects, &Project.to_map/1)}, socket}
  end

  @impl true
  def join("project:" <> name, _payload, socket) do
    # Subscribe to per-project PubSub
    Phoenix.PubSub.subscribe(Lantern.PubSub, "project:#{name}")

    case Manager.get(name) do
      nil ->
        {:error, %{reason: "project not found"}}

      project ->
        # Get recent logs if available
        logs =
          try do
            ProcessRunner.get_logs(name)
          rescue
            _ -> []
          catch
            :exit, _ -> []
          end

        {:ok, %{project: Project.to_map(project), logs: logs}, assign(socket, :project_name, name)}
    end
  end

  @impl true
  def handle_info({:status_change, project_name, status}, socket) do
    push(socket, "status_change", %{project: project_name, status: status})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:log_line, _project_name, line}, socket) do
    push(socket, "log_line", %{line: line})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
