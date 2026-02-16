defmodule Lantern.MCP.Tools.GetProjectDocs do
  @moduledoc "Read documentation files for a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, DocServer}

  schema do
    field(:name, :string, required: true, description: "Project name")
    field(:path, :string, description: "Specific doc path to read (omit to list all)")
  end

  def execute(%{name: name} = params, frame) do
    case Manager.get(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      project ->
        if params[:path] do
          case DocServer.read(project, params.path) do
            {:ok, content} ->
              {:reply, Response.tool() |> Response.text(content), frame}

            {:error, :not_found} ->
              {:error, Error.execution("Document '#{params.path}' not found"), frame}

            {:error, reason} ->
              {:error, Error.execution(inspect(reason)), frame}
          end
        else
          docs = DocServer.list(project)
          {:reply, Response.tool() |> Response.json(docs), frame}
        end
    end
  end
end
