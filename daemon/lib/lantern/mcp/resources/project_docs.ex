defmodule Lantern.MCP.Resources.ProjectDocs do
  @moduledoc "Project documentation content"
  use Hermes.Server.Component,
    type: :resource,
    uri: "lantern:///projects/docs"

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, DocServer}

  def read(%{"uri" => uri}, frame) do
    case parse_uri(uri) do
      :all ->
        content =
          Manager.list()
          |> Enum.map(fn project ->
            %{
              name: project.name,
              docs: read_project_docs(project)
            }
          end)
          |> Enum.reject(fn %{docs: docs} -> docs == [] end)

        {:reply, Response.resource() |> Response.text(Jason.encode!(content)), frame}

      {:project, name} ->
        case Manager.get(name) do
          nil ->
            {:error, Error.resource(:not_found, %{uri: uri}), frame}

          project ->
            content = %{name: project.name, docs: read_project_docs(project)}
            {:reply, Response.resource() |> Response.text(Jason.encode!(content)), frame}
        end

      :invalid ->
        {:error, Error.resource(:not_found, %{uri: uri}), frame}
    end
  end

  defp parse_uri(uri) when is_binary(uri) do
    cond do
      uri == __MODULE__.uri() ->
        :all

      String.starts_with?(uri, "lantern:///projects/") ->
        rest = String.replace_prefix(uri, "lantern:///projects/", "")

        case String.split(rest, "/docs", parts: 2) do
          [name, ""] when name != "" -> {:project, URI.decode_www_form(name)}
          _ -> :invalid
        end

      true ->
        :invalid
    end
  end

  defp parse_uri(_), do: :invalid

  defp read_project_docs(project) do
    project
    |> DocServer.list()
    |> Enum.filter(fn d -> d.exists end)
    |> Enum.map(fn doc ->
      case DocServer.read(project, doc.path) do
        {:ok, text} -> %{path: doc.path, kind: doc.kind, content: text}
        _ -> %{path: doc.path, kind: doc.kind, content: "(unreadable)"}
      end
    end)
  end
end
