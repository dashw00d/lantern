defmodule LanternWeb.ToolController do
  use LanternWeb, :controller

  alias Lantern.Health.Checker
  alias Lantern.Projects.{DocServer, Manager, Project}

  @default_tool_kinds MapSet.new([:service, :capability, :tool, :website])

  def index(conn, params) do
    include_hidden = truthy_param?(params["include_hidden"])
    allowed_kinds = resolve_kind_filter(params)
    health_results = Checker.all()

    tools =
      Manager.list()
      |> Enum.filter(&visible_tool?(&1, include_hidden, allowed_kinds))
      |> Enum.map(&tool_summary(&1, health_results))

    json(conn, %{data: tools, tools: tools, meta: %{count: length(tools)}})
  end

  def show(conn, %{"id" => id} = params) do
    include_hidden = truthy_param?(params["include_hidden"])
    allowed_kinds = resolve_kind_filter(params)

    case fetch_tool(id, include_hidden, allowed_kinds) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Tool '#{id}' not found"})

      project ->
        health = Checker.get(project.name)
        detail = tool_detail(project, health)
        json(conn, %{data: detail, tool: detail})
    end
  end

  def docs(conn, %{"id" => id} = params) do
    include_hidden = truthy_param?(params["include_hidden"])
    allowed_kinds = resolve_kind_filter(params)

    case fetch_tool(id, include_hidden, allowed_kinds) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Tool '#{id}' not found"})

      project ->
        docs =
          project
          |> DocServer.list()
          |> Enum.map(&read_doc(project, &1))

        payload = %{
          id: tool_id(project),
          tool_id: tool_id(project),
          name: project.name,
          docs: docs
        }

        json(conn, %{data: payload})
    end
  end

  defp fetch_tool(id, include_hidden, allowed_kinds) do
    case Manager.get_by_id(id) do
      %Project{} = project ->
        if visible_tool?(project, include_hidden, allowed_kinds), do: project, else: nil

      _ ->
        nil
    end
  end

  defp visible_tool?(%Project{kind: kind, enabled: enabled}, include_hidden, allowed_kinds) do
    include_visibility = include_hidden or enabled != false
    include_kind = MapSet.member?(allowed_kinds, kind)
    include_visibility and include_kind
  end

  defp resolve_kind_filter(params) do
    kinds =
      [params["kind"], params["kinds"]]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&to_kind_values/1)
      |> Enum.reduce(MapSet.new(), fn raw_kind, acc ->
        case parse_kind(raw_kind) do
          nil -> acc
          kind -> MapSet.put(acc, kind)
        end
      end)

    if MapSet.size(kinds) == 0, do: @default_tool_kinds, else: kinds
  end

  defp to_kind_values(value) when is_list(value), do: value

  defp to_kind_values(value) when is_binary(value) do
    String.split(value, ",", trim: true)
  end

  defp to_kind_values(_), do: []

  defp parse_kind(value) when is_atom(value), do: parse_kind(Atom.to_string(value))

  defp parse_kind(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "service" -> :service
      "project" -> :project
      "capability" -> :capability
      "tool" -> :tool
      "website" -> :website
      _ -> nil
    end
  end

  defp parse_kind(_), do: nil

  defp tool_id(%Project{id: id}) when is_binary(id) and id != "", do: id
  defp tool_id(%Project{name: name}), do: name

  defp tool_summary(%Project{} = project, health_results) do
    routing = project.routing || %{}
    health = Map.get(health_results, project.name)
    triggers = Map.get(routing, :triggers) || []
    agents = Map.get(routing, :agents) || []
    risk = Map.get(routing, :risk)

    docs_available = Project.merged_docs(project)
    endpoints_available = Project.merged_endpoints(project)

    %{
      id: tool_id(project),
      name: project.name,
      kind: project.kind,
      description: project.description,
      tags: project.tags || [],
      enabled: project.enabled != false,
      status: project.status,
      domain: project.domain,
      base_url: project.base_url,
      upstream_url: project.upstream_url,
      health_endpoint: project.health_endpoint,
      health_status: resolve_health_status(project, health),
      requires_confirmation: Map.get(routing, :requires_confirmation, false),
      max_concurrent: Map.get(routing, :max_concurrent, 1),
      triggers: triggers,
      risk: risk,
      agents: agents,
      docs_count: length(docs_available),
      endpoints_count: length(endpoints_available),
      discovery_refreshed_at: get_in(project.discovery || %{}, [:refreshed_at])
    }
  end

  defp tool_detail(%Project{} = project, health) do
    Map.merge(tool_summary(project, %{project.name => health}), %{
      path: project.path,
      repo_path: project.path,
      run_cmd: project.run_cmd,
      endpoints: project.endpoints || [],
      discovered_endpoints: project.discovered_endpoints || [],
      endpoints_available: Project.merged_endpoints(project),
      docs: project.docs || [],
      discovered_docs: project.discovered_docs || [],
      docs_available: Project.merged_docs(project),
      docs_paths: Enum.map(Project.merged_docs(project), fn doc -> doc.path end),
      docs_auto: project.docs_auto || %{},
      api_auto: project.api_auto || %{},
      discovery: project.discovery || %{},
      routing: project.routing,
      depends_on: project.depends_on || [],
      repo_url: project.repo_url
    })
  end

  defp resolve_health_status(%Project{enabled: false}, _health), do: "disabled"
  defp resolve_health_status(_project, nil), do: "unknown"
  defp resolve_health_status(_project, %{status: status}) when is_binary(status), do: status
  defp resolve_health_status(_project, %{status: status}), do: to_string(status)
  defp resolve_health_status(_project, _health), do: "unknown"

  defp read_doc(project, doc) do
    base = %{
      path: doc.path,
      kind: doc.kind,
      source: Map.get(doc, :source),
      exists: doc.exists,
      size: doc.size,
      mtime: doc.mtime
    }

    if doc.exists do
      case DocServer.read(project, doc.path) do
        {:ok, content} -> Map.put(base, :content, content)
        {:error, reason} -> base |> Map.put(:content, nil) |> Map.put(:error, inspect(reason))
      end
    else
      base
      |> Map.put(:content, nil)
      |> Map.put(:error, "not_found")
    end
  end

  defp truthy_param?(value) when value in [true, 1], do: true

  defp truthy_param?(value) when is_binary(value) do
    String.downcase(String.trim(value)) in ["1", "true", "yes", "on"]
  end

  defp truthy_param?(_), do: false
end
