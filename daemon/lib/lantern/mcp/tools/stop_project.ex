defmodule Lantern.MCP.Tools.StopProject do
  @moduledoc "Run deploy stop command for a project"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, DeployRunner}

  schema do
    field :name, :string, required: true, description: "Project name"
  end

  def execute(%{name: name}, frame) do
    case Manager.get(name) do
      nil ->
        {:error, Error.execution("Project '#{name}' not found"), frame}

      project ->
        case DeployRunner.execute(project, :stop) do
          {:ok, output} ->
            {:reply, Response.tool() |> Response.text(output), frame}

          {:error, %{output: output}} ->
            {:error, Error.execution(output), frame}

          {:error, msg} ->
            {:error, Error.execution(msg), frame}
        end
    end
  end
end
