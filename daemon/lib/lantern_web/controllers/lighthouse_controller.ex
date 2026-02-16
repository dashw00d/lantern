defmodule LanternWeb.LighthouseController do
  use LanternWeb, :controller

  alias Lantern.Projects.{DocServer, Manager, Project}

  def index(conn, %{"project" => raw_name}) do
    with {:ok, name} <- decode_name(raw_name),
         %Project{} = project <- Manager.get(name) do
      docs = DocServer.list(project)
      html = render_index(project, docs)

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html)
    else
      nil ->
        not_found_html(conn, raw_name)

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_project", message: "Invalid project name"})
    end
  end

  def show(conn, %{"project" => raw_name, "filename" => filename_parts}) do
    filename = Path.join(filename_parts)

    with {:ok, name} <- decode_name(raw_name),
         %Project{} = project <- Manager.get(name),
         {:ok, content} <- DocServer.read(project, filename) do
      conn
      |> put_resp_content_type(content_type_for(filename))
      |> send_resp(200, content)
    else
      nil ->
        not_found_html(conn, raw_name)

      {:error, :path_traversal} ->
        conn
        |> put_status(:forbidden)
        |> send_resp(403, "Forbidden")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> send_resp(404, "Document not found")

      :error ->
        conn
        |> put_status(:bad_request)
        |> send_resp(400, "Invalid project name")

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> send_resp(422, inspect(reason))
    end
  end

  defp render_index(project, docs) do
    project_segment = URI.encode_www_form(project.name)

    rows =
      Enum.map_join(docs, "", fn doc ->
        href = "/#{project_segment}/docs/#{encode_relative_path(doc.path)}"
        status = if doc.exists, do: "available", else: "missing"

        """
        <li>
          <a href="#{href}">#{escape_html(doc.path)}</a>
          <span>#{escape_html(doc.kind || "unknown")}</span>
          <span>#{status}</span>
        </li>
        """
      end)

    """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>#{escape_html(project.name)} Docs</title>
        <style>
          body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; margin: 2rem; color: #111827; }
          h1 { margin: 0 0 0.5rem; }
          p { color: #4b5563; }
          ul { list-style: none; padding: 0; margin: 1.5rem 0 0; border: 1px solid #e5e7eb; border-radius: 0.5rem; }
          li { display: grid; grid-template-columns: 1fr auto auto; gap: 1rem; padding: 0.75rem 1rem; border-bottom: 1px solid #f3f4f6; }
          li:last-child { border-bottom: none; }
          a { color: #0f766e; text-decoration: none; }
          a:hover { text-decoration: underline; }
          span { color: #6b7280; font-size: 0.875rem; }
        </style>
      </head>
      <body>
        <h1>#{escape_html(project.name)} docs</h1>
        <p>Served by Lantern at lighthouse#{escape_html(Application.get_env(:lantern, :tld, ".glow"))}.</p>
        <ul>
          #{rows}
        </ul>
      </body>
    </html>
    """
  end

  defp encode_relative_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&URI.encode_www_form/1)
    |> Enum.join("/")
  end

  defp decode_name(raw_name) when is_binary(raw_name) do
    case URI.decode_www_form(raw_name) do
      "" -> :error
      decoded -> {:ok, decoded}
    end
  rescue
    _ -> :error
  end

  defp decode_name(_), do: :error

  defp not_found_html(conn, raw_name) do
    conn
    |> put_status(:not_found)
    |> put_resp_content_type("text/html")
    |> send_resp(404, "<h1>Project not found</h1><p>#{escape_html(raw_name)}</p>")
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

  defp escape_html(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp escape_html(value), do: value |> to_string() |> escape_html()
end
