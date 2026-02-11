defmodule LanternWeb.ProjectController do
  use LanternWeb, :controller

  alias Lantern.Projects.{Manager, Project}

  def index(conn, _params) do
    projects = Manager.list()
    json(conn, %{data: Enum.map(projects, &Project.to_map/1)})
  end

  def show(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        json(conn, %{data: Project.to_map(project)})
    end
  end

  def scan(conn, _params) do
    case Manager.scan() do
      {:ok, projects} ->
        json(conn, %{data: Enum.map(projects, &Project.to_map/1), meta: %{count: length(projects)}})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "scan_failed", message: inspect(reason)})
    end
  end

  def activate(conn, %{"name" => name}) do
    case Manager.activate(name) do
      {:ok, project} ->
        json(conn, %{data: Project.to_map(project)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "activation_failed", message: inspect(reason)})
    end
  end

  def deactivate(conn, %{"name" => name}) do
    case Manager.deactivate(name) do
      {:ok, project} ->
        json(conn, %{data: Project.to_map(project)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "deactivation_failed", message: inspect(reason)})
    end
  end

  def restart(conn, %{"name" => name}) do
    case Manager.restart(name) do
      {:ok, project} ->
        json(conn, %{data: Project.to_map(project)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "restart_failed", message: inspect(reason)})
    end
  end

  def update(conn, %{"name" => name} = params) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      _project ->
        # For now, return the project as-is. Full update support comes later.
        json(conn, %{data: %{name: name, updated: Map.drop(params, ["name"])}})
    end
  end
end
