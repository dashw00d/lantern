defmodule LanternWeb.ProjectController do
  use LanternWeb, :controller

  require Logger

  alias Lantern.Projects.{Manager, Project}
  alias Lantern.Projects.ProcessRunner

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
        json(conn, %{
          data: Enum.map(projects, &Project.to_map/1),
          meta: %{count: length(projects)}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "scan_failed", message: inspect(reason)})
    end
  end

  def logs(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      _project ->
        stream_logs(conn, name)
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

  defp stream_logs(conn, name) do
    Phoenix.PubSub.subscribe(Lantern.PubSub, "project:#{name}")

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    conn
    |> send_recent_logs(name)
    |> stream_logs_loop(name)
  end

  defp send_recent_logs(conn, name) do
    logs =
      try do
        ProcessRunner.get_logs(name)
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    Enum.reduce_while(logs, conn, fn line, acc ->
      case send_sse_chunk(acc, line) do
        {:ok, updated_conn} ->
          {:cont, updated_conn}

        {:error, :closed} ->
          {:halt, acc}

        {:error, reason} ->
          Logger.debug("Failed streaming historical log for #{name}: #{inspect(reason)}")
          {:halt, acc}
      end
    end)
  end

  defp stream_logs_loop(conn, name) do
    receive do
      {:log_line, ^name, line} ->
        case send_sse_chunk(conn, line) do
          {:ok, updated_conn} ->
            stream_logs_loop(updated_conn, name)

          {:error, :closed} ->
            conn

          {:error, reason} ->
            Logger.debug("Failed streaming log chunk for #{name}: #{inspect(reason)}")
            conn
        end
    after
      25_000 ->
        case chunk(conn, ": keepalive\n\n") do
          {:ok, updated_conn} -> stream_logs_loop(updated_conn, name)
          {:error, _reason} -> conn
        end
    end
  end

  defp send_sse_chunk(conn, line) do
    normalized_lines =
      line
      |> to_string()
      |> String.replace("\r", "")
      |> String.trim_trailing("\n")
      |> String.split("\n", trim: true)

    case normalized_lines do
      [] ->
        {:ok, conn}

      lines ->
        Enum.reduce_while(lines, {:ok, conn}, fn current_line, {:ok, acc} ->
          case chunk(acc, "data: #{current_line}\n\n") do
            {:ok, updated_conn} -> {:cont, {:ok, updated_conn}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
    end
  end
end
