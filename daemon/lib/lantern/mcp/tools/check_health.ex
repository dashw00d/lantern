defmodule Lantern.MCP.Tools.CheckHealth do
  @moduledoc "Check health status of projects"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.Health.Checker

  schema do
    field(:name, :string, description: "Project name (omit for all projects)")
  end

  def execute(params, frame) do
    if params[:name] do
      case Checker.get(params.name) do
        nil ->
          {:reply,
           Response.tool()
           |> Response.json(%{status: "unknown", message: "No health data for '#{params.name}'"}),
           frame}

        health ->
          {:reply, Response.tool() |> Response.json(health), frame}
      end
    else
      {:reply, Response.tool() |> Response.json(Checker.all()), frame}
    end
  end
end
