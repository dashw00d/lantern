defmodule Lantern.MCP.Tools.ListTools do
  @moduledoc "List all available tools registered in Lantern"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  @valid_statuses ~w(running stopped error starting stopping needs_config)

  schema do
    field(:tag, :string, description: "Filter by tag")
    field(:status, :string, description: "Filter by status (running, stopped, error)")
  end

  def execute(params, frame) do
    tools =
      Manager.list()
      |> Enum.filter(fn p -> p.kind == :tool end)
      |> maybe_filter_tag(params[:tag])
      |> maybe_filter_status(params[:status])
      |> Enum.map(&tool_summary/1)

    {:reply, Response.tool() |> Response.json(tools), frame}
  end

  defp tool_summary(%Project{} = p) do
    %{
      name: p.name,
      description: p.description,
      domain: p.domain,
      status: p.status,
      tags: p.tags,
      endpoints_available: Project.merged_endpoints(p)
    }
  end

  defp maybe_filter_tag(tools, nil), do: tools
  defp maybe_filter_tag(tools, tag), do: Enum.filter(tools, fn p -> tag in (p.tags || []) end)

  defp maybe_filter_status(tools, nil), do: tools

  defp maybe_filter_status(tools, status) when status in @valid_statuses do
    status_atom = String.to_existing_atom(status)
    Enum.filter(tools, fn p -> p.status == status_atom end)
  end

  defp maybe_filter_status(tools, _status), do: tools
end
