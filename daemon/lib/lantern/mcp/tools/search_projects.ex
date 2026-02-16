defmodule Lantern.MCP.Tools.SearchProjects do
  @moduledoc "Search projects by name, tag, or description"
  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias Lantern.Projects.{Manager, Project}

  schema do
    field(:query, :string,
      required: true,
      description: "Search query (matches name, description, tags)"
    )
  end

  def execute(%{query: query}, frame) do
    q = String.downcase(query)

    results =
      Manager.list()
      |> Enum.filter(fn p ->
        String.contains?(String.downcase(p.name), q) ||
          (p.description && String.contains?(String.downcase(p.description), q)) ||
          Enum.any?(p.tags || [], fn tag -> String.contains?(String.downcase(tag), q) end)
      end)
      |> Enum.map(&Project.to_map/1)

    {:reply, Response.tool() |> Response.json(results), frame}
  end
end
