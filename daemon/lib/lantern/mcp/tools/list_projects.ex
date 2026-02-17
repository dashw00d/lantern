defmodule Lantern.MCP.Tools.ListProjects do
  @moduledoc "List all projects with metadata"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.Projects.{Manager, Project}

  @valid_kinds ~w(service project capability website tool)
  @valid_statuses ~w(running stopped error starting stopping needs_config)

  schema do
    field(:tag, :string, description: "Filter by tag")

    field(:kind, :string,
      description: "Filter by kind (service, project, capability, website, tool)"
    )

    field(:status, :string, description: "Filter by status (running, stopped, error)")
  end

  def execute(params, frame) do
    Timeout.run(frame, 10_000, fn ->
      projects =
        Manager.list()
        |> maybe_filter_tag(params[:tag])
        |> maybe_filter_kind(params[:kind])
        |> maybe_filter_status(params[:status])
        |> Enum.map(&Project.to_map/1)

      {:reply, Response.tool() |> Response.json(projects), frame}
    end)
  end

  defp maybe_filter_tag(projects, nil), do: projects

  defp maybe_filter_tag(projects, tag),
    do: Enum.filter(projects, fn p -> tag in (p.tags || []) end)

  defp maybe_filter_kind(projects, nil), do: projects

  defp maybe_filter_kind(projects, kind) when kind in @valid_kinds do
    kind_atom = String.to_existing_atom(kind)
    Enum.filter(projects, fn p -> p.kind == kind_atom end)
  end

  defp maybe_filter_kind(projects, _kind), do: projects

  defp maybe_filter_status(projects, nil), do: projects

  defp maybe_filter_status(projects, status) when status in @valid_statuses do
    status_atom = String.to_existing_atom(status)
    Enum.filter(projects, fn p -> p.status == status_atom end)
  end

  defp maybe_filter_status(projects, _status), do: projects
end
