defmodule Lantern.MCP.Tools.StartProject do
  @moduledoc "Start a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.Projects.Manager

  schema do
    field(:name, :string, required: true, description: "Project name")
  end

  def execute(%{name: name}, frame) do
    Timeout.run(frame, 45_000, fn ->
      case Manager.get(name) do
        nil ->
          {:error, Error.execution("Project '#{name}' not found"), frame}

        %{status: :running} = project ->
          msg = "#{project.name} is already running (port: #{project.port})"
          {:reply, Response.tool() |> Response.text(msg), frame}

        _project ->
          case Manager.activate(name) do
            {:ok, updated_project} ->
              msg = "Started #{updated_project.name} (status: #{updated_project.status})"
              {:reply, Response.tool() |> Response.text(msg), frame}

            {:error, reason} when is_binary(reason) ->
              if String.contains?(reason, "already_started") do
                project = Manager.get(name)
                msg = "#{project.name} is already running (port: #{project.port})"
                {:reply, Response.tool() |> Response.text(msg), frame}
              else
                {:error, Error.execution(reason), frame}
              end

            {:error, reason} ->
              {:error, Error.execution(inspect(reason)), frame}
          end
      end
    end)
  end
end
