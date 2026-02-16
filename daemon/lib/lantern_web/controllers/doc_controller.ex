defmodule LanternWeb.DocController do
  use LanternWeb, :controller

  alias Lantern.Projects.{Manager, DocServer}

  def index(conn, %{"name" => name}) do
    with_project(conn, name, fn project ->
      docs = DocServer.list(project)
      json(conn, %{data: docs})
    end)
  end

  def show(conn, %{"name" => name, "filename" => filename_parts}) do
    filename = Path.join(filename_parts)

    with_project(conn, name, fn project ->
      case DocServer.read(project, filename) do
        {:ok, content} ->
          conn
          |> put_resp_content_type(content_type_for(filename))
          |> send_resp(200, content)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found", message: "Document '#{filename}' not found"})

        {:error, :path_traversal} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", message: "Invalid path"})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "read_failed", message: inspect(reason)})
      end
    end)
  end

  defp content_type_for(filename) do
    case Path.extname(filename) do
      ".md" -> "text/markdown"
      ".txt" -> "text/plain"
      ".html" -> "text/html"
      ".json" -> "application/json"
      ".yaml" -> "text/yaml"
      ".yml" -> "text/yaml"
      _ -> "text/plain"
    end
  end

  defp with_project(conn, name, fun) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        fun.(project)
    end
  end
end
