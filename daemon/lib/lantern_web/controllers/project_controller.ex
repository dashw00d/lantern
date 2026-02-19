defmodule LanternWeb.ProjectController do
  use LanternWeb, :controller

  require Logger

  alias Lantern.Projects.{Manager, Project, ProcessRunner}

  def index(conn, params) do
    case safe_manager_call(fn -> Manager.list() end) do
      {:ok, projects} ->
        filtered = maybe_filter_hidden(projects, include_hidden?(params))
        json(conn, %{data: Enum.map(filtered, &Project.to_map/1)})

      {:error, :timeout} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{error: "list_timeout", message: "Listing projects timed out"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "list_failed", message: inspect(reason)})
    end
  end

  def show(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        json(conn, %{data: Project.to_map(project)})
    end
  end

  def scan(conn, params) do
    case Manager.scan() do
      {:ok, projects} ->
        filtered = maybe_filter_hidden(projects, include_hidden?(params))

        json(conn, %{
          data: Enum.map(filtered, &Project.to_map/1),
          meta: %{count: length(filtered)}
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "scan_failed", message: inspect(reason)})
    end
  end

  def logs(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      _project ->
        stream_logs(conn, name)
    end
  end

  def activate(conn, %{"name" => name}) do
    case safe_manager_call(fn -> Manager.activate(name) end) do
      {:ok, {:ok, project}} ->
        json(conn, %{data: Project.to_map(project)})

      {:ok, {:error, :not_found}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:ok, {:error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "activation_failed", message: inspect(reason)})

      {:error, :timeout} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{error: "activation_timeout", message: "Activation timed out"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "activation_failed", message: inspect(reason)})
    end
  end

  def deactivate(conn, %{"name" => name}) do
    case safe_manager_call(fn -> Manager.deactivate(name) end) do
      {:ok, {:ok, project}} ->
        json(conn, %{data: Project.to_map(project)})

      {:ok, {:error, :not_found}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:ok, {:error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "deactivation_failed", message: inspect(reason)})

      {:error, :timeout} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{error: "deactivation_timeout", message: "Deactivation timed out"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "deactivation_failed", message: inspect(reason)})
    end
  end

  def restart(conn, %{"name" => name}) do
    case safe_manager_call(fn -> Manager.restart(name) end) do
      {:ok, {:ok, project}} ->
        json(conn, %{data: Project.to_map(project)})

      {:ok, {:error, :not_found}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:ok, {:error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "restart_failed", message: inspect(reason)})

      {:error, :timeout} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{error: "restart_timeout", message: "Restart timed out"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "restart_failed", message: inspect(reason)})
    end
  end

  def reset(conn, %{"name" => name}) do
    case Manager.reset_from_manifest(name) do
      {:ok, project} ->
        json(conn, %{data: Project.to_map(project)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:error, :manifest_not_found} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "manifest_not_found",
          message: "No lantern.yaml or lantern.yml found for '#{name}'"
        })

      {:error, {:validation, reasons}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_manifest", message: format_validation_errors(reasons)})

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "reset_failed", message: reason})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "reset_failed", message: inspect(reason)})
    end
  end

  def update(conn, %{"name" => name} = params) do
    do_update(conn, name, params)
  end

  def create(conn, params) do
    with {:ok, attrs} <- parse_create_params(params) do
      case Manager.register(attrs) do
        {:ok, project} ->
          conn
          |> put_status(:created)
          |> json(%{data: Project.to_map(project)})

        {:error, :already_exists} ->
          conn
          |> put_status(:conflict)
          |> json(%{error: "already_exists", message: "Project '#{attrs.name}' already exists"})

        {:error, {:validation, reasons}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "invalid_project", message: format_validation_errors(reasons)})

        {:error, reason} when is_binary(reason) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "registration_failed", message: reason})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "registration_failed", message: inspect(reason)})
      end
    else
      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_project", message: reason})
    end
  end

  def patch(conn, %{"name" => name} = params) do
    do_update(conn, name, params)
  end

  defp do_update(conn, name, params) do
    with {:ok, updates} <- parse_update_params(params),
         {:ok, project} <- Manager.update(name, updates) do
      json(conn, %{data: Project.to_map(project)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      {:error, {:validation, reasons}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_update", message: format_validation_errors(reasons)})

      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "already_exists", message: "Project name is already in use"})

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_update", message: reason})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "update_failed", message: inspect(reason)})
    end
  end

  def delete(conn, %{"name" => name}) do
    case Manager.deregister(name) do
      :ok ->
        json(conn, %{data: %{deleted: name}})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})
    end
  end

  def endpoints(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        json(conn, %{data: Project.merged_endpoints(project)})
    end
  end

  def discovery(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        json(conn, %{
          data: %{
            name: project.name,
            docs_auto: project.docs_auto || %{},
            api_auto: project.api_auto || %{},
            discovered_docs: project.discovered_docs || [],
            discovered_endpoints: project.discovered_endpoints || [],
            docs_available: Project.merged_docs(project),
            endpoints_available: Project.merged_endpoints(project),
            discovery: project.discovery || %{}
          }
        })
    end
  end

  def refresh_discovery(conn, %{"name" => name}) do
    case Manager.refresh_discovery(name) do
      {:ok, project} ->
        json(conn, %{data: Project.to_map(project)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})
    end
  end

  def refresh_discovery_all(conn, _params) do
    case Manager.refresh_discovery(:all) do
      {:ok, projects} ->
        json(conn, %{
          data: Enum.map(projects, &Project.to_map/1),
          meta: %{count: length(projects)}
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "refresh_failed", message: inspect(reason)})
    end
  end

  def dependencies(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        json(conn, %{data: %{project: project.name, depends_on: project.depends_on || []}})
    end
  end

  def dependents(conn, %{"name" => name}) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      _project ->
        depended_by =
          Manager.list()
          |> Enum.filter(fn project -> name in (project.depends_on || []) end)
          |> Enum.map(& &1.name)

        json(conn, %{data: %{project: name, depended_by: depended_by}})
    end
  end

  @updatable_fields ~w(
    type domain path root run_cmd run_cwd run_env features template description
    kind base_url upstream_url health_endpoint repo_url tags enabled deploy docs
    endpoints docs_auto api_auto depends_on routing new_name
  )a

  @updatable_field_strings Enum.map(@updatable_fields, &Atom.to_string/1)

  @create_optional_fields ~w(
    id description kind base_url upstream_url health_endpoint repo_url tags enabled
    deploy docs endpoints docs_auto api_auto depends_on type domain root run_cmd run_cwd run_env
    features template routing
  )

  @field_to_atom Map.new(
                   (@updatable_field_strings ++ @create_optional_fields)
                   |> Enum.uniq(),
                   fn field -> {field, String.to_atom(field)} end
                 )

  @type_map %{
    "php" => :php,
    "proxy" => :proxy,
    "static" => :static,
    "unknown" => :unknown
  }

  @kind_map %{
    "service" => :service,
    "project" => :project,
    "capability" => :capability,
    "website" => :website,
    "tool" => :tool
  }

  @deploy_key_map %{
    "install" => :install,
    "start" => :start,
    "stop" => :stop,
    "restart" => :restart,
    "logs" => :logs,
    "status" => :status,
    "env_file" => :env_file
  }

  @endpoint_key_map %{
    "method" => :method,
    "path" => :path,
    "description" => :description,
    "category" => :category,
    "risk" => :risk,
    "body_hint" => :body_hint,
    "params" => :params
  }

  @routing_key_map %{
    "aliases" => :aliases,
    "paths" => :paths,
    "websocket" => :websocket,
    "triggers" => :triggers,
    "risk" => :risk,
    "requires_confirmation" => :requires_confirmation,
    "max_concurrent" => :max_concurrent,
    "agents" => :agents
  }

  defp parse_create_params(params) when is_map(params) do
    with {:ok, name} <- normalize_required_string(Map.get(params, "name"), "name"),
         {:ok, path} <- normalize_path(Map.get(params, "path")) do
      attrs = %{name: name, path: path}

      Enum.reduce_while(@create_optional_fields, {:ok, attrs}, fn field, {:ok, acc} ->
        case Map.fetch(params, field) do
          :error ->
            {:cont, {:ok, acc}}

          {:ok, value} ->
            case normalize_field(field, value) do
              {:ok, normalized} ->
                key = Map.fetch!(@field_to_atom, field)
                {:cont, {:ok, Map.put(acc, key, normalized)}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
        end
      end)
    end
  end

  defp parse_update_params(params) when is_map(params) do
    updates =
      params
      |> Map.drop(["name"])
      |> Map.take(@updatable_field_strings)

    Enum.reduce_while(updates, {:ok, %{}}, fn {field, value}, {:ok, acc} ->
      case normalize_field(field, value) do
        {:ok, normalized} ->
          key = Map.fetch!(@field_to_atom, field)
          {:cont, {:ok, Map.put(acc, key, normalized)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_field("type", value), do: normalize_type(value)
  defp normalize_field("kind", value), do: normalize_kind(value)
  defp normalize_field("path", value), do: normalize_required_string(value, "path")
  defp normalize_field("new_name", value), do: normalize_required_string(value, "new_name")
  defp normalize_field("enabled", value), do: normalize_enabled(value)
  defp normalize_field("run_env", value), do: normalize_run_env(value)
  defp normalize_field("features", value), do: normalize_features(value)
  defp normalize_field("tags", value), do: normalize_string_list(value, "tags")
  defp normalize_field("depends_on", value), do: normalize_string_list(value, "depends_on")
  defp normalize_field("deploy", value), do: normalize_deploy(value)
  defp normalize_field("docs", value), do: normalize_docs(value)
  defp normalize_field("endpoints", value), do: normalize_endpoints(value)
  defp normalize_field("docs_auto", value), do: normalize_discovery_config(value, "docs_auto")
  defp normalize_field("api_auto", value), do: normalize_discovery_config(value, "api_auto")
  defp normalize_field("routing", value), do: normalize_routing(value)

  defp normalize_field(field, value)
       when field in [
              "id",
              "description",
              "domain",
              "root",
              "run_cmd",
              "run_cwd",
              "template",
              "base_url",
              "upstream_url",
              "health_endpoint",
              "repo_url"
            ] do
    normalize_optional_string(value, field)
  end

  defp normalize_field(_field, value), do: {:ok, value}

  defp normalize_type(nil), do: {:ok, :unknown}
  defp normalize_type(value), do: normalize_enum(value, @type_map, "type")

  defp normalize_kind(nil), do: {:ok, :project}
  defp normalize_kind(value), do: normalize_enum(value, @kind_map, "kind")

  defp normalize_enum(value, valid_map, field) when is_atom(value) do
    if value in Map.values(valid_map) do
      {:ok, value}
    else
      {:error, "Invalid project #{field}: #{inspect(value)}"}
    end
  end

  defp normalize_enum(value, valid_map, field) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    case Map.get(valid_map, normalized) do
      nil -> {:error, "Invalid project #{field}: #{inspect(value)}"}
      atom -> {:ok, atom}
    end
  end

  defp normalize_enum(_value, _valid_map, field), do: {:error, "Invalid value for '#{field}'"}

  defp normalize_enabled(nil), do: {:ok, true}
  defp normalize_enabled(value) when is_boolean(value), do: {:ok, value}
  defp normalize_enabled(1), do: {:ok, true}
  defp normalize_enabled(0), do: {:ok, false}

  defp normalize_enabled(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      v when v in ["1", "true", "yes", "on"] -> {:ok, true}
      v when v in ["0", "false", "no", "off"] -> {:ok, false}
      _ -> {:error, "Invalid value for 'enabled'"}
    end
  end

  defp normalize_enabled(_), do: {:error, "Invalid value for 'enabled'"}

  defp normalize_run_env(nil), do: {:ok, %{}}

  defp normalize_run_env(value) when is_map(value) do
    {:ok,
     Map.new(value, fn {k, v} ->
       {to_string(k), to_string(v)}
     end)}
  end

  defp normalize_run_env(_), do: {:error, "Invalid value for 'run_env'"}

  defp normalize_features(nil), do: {:ok, %{}}
  defp normalize_features(value) when is_map(value), do: {:ok, value}
  defp normalize_features(_), do: {:error, "Invalid value for 'features'"}

  defp normalize_string_list(nil, _field), do: {:ok, []}

  defp normalize_string_list(value, _field) when is_list(value) do
    normalized =
      value
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, normalized}
  end

  defp normalize_string_list(value, field) when is_binary(value) do
    value
    |> String.split(~r/[\n,]/, trim: true)
    |> normalize_string_list(field)
  end

  defp normalize_string_list(_value, field), do: {:error, "Invalid value for '#{field}'"}

  defp normalize_deploy(nil), do: {:ok, %{}}

  defp normalize_deploy(value) when is_map(value) do
    normalized =
      Enum.reduce(value, %{}, fn {key, current_value}, acc ->
        case lookup_whitelist_key(@deploy_key_map, key) do
          nil ->
            acc

          atom_key ->
            Map.put(acc, atom_key, normalize_deploy_value(current_value))
        end
      end)

    {:ok, normalized}
  end

  defp normalize_deploy(_), do: {:error, "Invalid value for 'deploy'"}

  defp normalize_deploy_value(nil), do: nil

  defp normalize_deploy_value(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_deploy_value(value), do: to_string(value)

  defp normalize_docs(nil), do: {:ok, []}

  defp normalize_docs(value) when is_list(value) do
    Enum.reduce_while(value, {:ok, []}, fn entry, {:ok, acc} ->
      case normalize_doc_entry(entry) do
        {:ok, doc_entry} -> {:cont, {:ok, [doc_entry | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, docs} -> {:ok, Enum.reverse(docs)}
      other -> other
    end
  end

  defp normalize_docs(value) when is_binary(value) do
    value
    |> String.split(~r/[\n,]/, trim: true)
    |> normalize_docs()
  end

  defp normalize_docs(_), do: {:error, "Invalid value for 'docs'"}

  defp normalize_doc_entry(entry) when is_binary(entry) do
    path = String.trim(entry)

    if path == "" do
      {:error, "Invalid value for 'docs'"}
    else
      {:ok, %{path: path, kind: infer_doc_kind(path)}}
    end
  end

  defp normalize_doc_entry(entry) when is_map(entry) do
    path = entry["path"] || entry[:path]
    kind = entry["kind"] || entry[:kind]

    with {:ok, normalized_path} <- normalize_required_string(path, "docs.path") do
      normalized_kind =
        case kind do
          value when is_binary(value) ->
            trimmed = String.trim(value)
            if trimmed == "", do: infer_doc_kind(normalized_path), else: trimmed

          value when is_atom(value) ->
            value |> Atom.to_string() |> String.trim()

          _ ->
            infer_doc_kind(normalized_path)
        end

      {:ok, %{path: normalized_path, kind: normalized_kind}}
    end
  end

  defp normalize_doc_entry(_), do: {:error, "Invalid value for 'docs'"}

  defp infer_doc_kind(path) when is_binary(path) do
    downcased = String.downcase(path)

    cond do
      String.contains?(downcased, "readme") -> "readme"
      String.contains?(downcased, "changelog") -> "changelog"
      String.contains?(downcased, "contributing") -> "contributing"
      String.ends_with?(downcased, ".md") -> "markdown"
      String.ends_with?(downcased, ".txt") -> "text"
      true -> "unknown"
    end
  end

  defp normalize_endpoints(nil), do: {:ok, []}

  defp normalize_endpoints(value) when is_list(value) do
    Enum.reduce_while(value, {:ok, []}, fn entry, {:ok, acc} ->
      case normalize_endpoint_entry(entry) do
        {:ok, endpoint} -> {:cont, {:ok, [endpoint | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, endpoints} -> {:ok, Enum.reverse(endpoints)}
      other -> other
    end
  end

  defp normalize_endpoints(_), do: {:error, "Invalid value for 'endpoints'"}

  defp normalize_endpoint_entry(entry) when is_map(entry) do
    method = entry["method"] || entry[:method]
    path = entry["path"] || entry[:path]

    with {:ok, normalized_method} <- normalize_required_string(method, "endpoints.method"),
         {:ok, normalized_path} <- normalize_required_string(path, "endpoints.path") do
      normalized =
        Enum.reduce(entry, %{method: String.upcase(normalized_method), path: normalized_path}, fn
          {key, value}, acc ->
            case lookup_whitelist_key(@endpoint_key_map, key) do
              nil ->
                acc

              :method ->
                acc

              :path ->
                acc

              atom_key ->
                Map.put(acc, atom_key, value)
            end
        end)

      {:ok, normalized}
    end
  end

  defp normalize_endpoint_entry(_), do: {:error, "Invalid value for 'endpoints'"}

  defp normalize_routing(nil), do: {:ok, nil}

  defp normalize_routing(value) when is_map(value) do
    normalized =
      Enum.reduce(value, %{}, fn {key, current_value}, acc ->
        case lookup_whitelist_key(@routing_key_map, key) do
          nil ->
            acc

          :aliases ->
            Map.put(acc, :aliases, normalize_simple_string_list(current_value))

          :triggers ->
            Map.put(acc, :triggers, normalize_simple_string_list(current_value))

          atom_key ->
            Map.put(acc, atom_key, current_value)
        end
      end)

    {:ok, normalized}
  end

  defp normalize_routing(_), do: {:error, "Invalid value for 'routing'"}

  defp normalize_discovery_config(nil, _field), do: {:ok, %{}}

  defp normalize_discovery_config(value, _field) when is_map(value) do
    normalized =
      value
      |> Enum.reduce(%{}, fn {key, current_value}, acc ->
        normalized_key =
          key
          |> to_string()
          |> String.trim()
          |> String.downcase()

        case normalized_key do
          "enabled" -> Map.put(acc, :enabled, normalize_discovery_bool(current_value))
          "patterns" -> Map.put(acc, :patterns, normalize_simple_string_list(current_value))
          "ignore" -> Map.put(acc, :ignore, normalize_simple_string_list(current_value))
          "sources" -> Map.put(acc, :sources, normalize_simple_string_list(current_value))
          "candidates" -> Map.put(acc, :candidates, normalize_simple_string_list(current_value))
          "max_files" -> Map.put(acc, :max_files, normalize_positive_int(current_value))
          "max_bytes" -> Map.put(acc, :max_bytes, normalize_positive_int(current_value))
          "timeout_ms" -> Map.put(acc, :timeout_ms, normalize_positive_int(current_value))
          "max_endpoints" -> Map.put(acc, :max_endpoints, normalize_positive_int(current_value))
          _ -> acc
        end
      end)
      |> Enum.reject(fn {_key, current_value} -> is_nil(current_value) end)
      |> Map.new()

    {:ok, normalized}
  end

  defp normalize_discovery_config(_value, field), do: {:error, "Invalid value for '#{field}'"}

  defp normalize_simple_string_list(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_simple_string_list(_), do: []

  defp normalize_discovery_bool(value) when value in [true, 1, "1"], do: true
  defp normalize_discovery_bool(value) when value in [false, 0, "0"], do: false

  defp normalize_discovery_bool(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      v when v in ["true", "yes", "on"] -> true
      v when v in ["false", "no", "off"] -> false
      _ -> nil
    end
  end

  defp normalize_discovery_bool(_), do: nil

  defp normalize_positive_int(value) when is_integer(value) and value > 0, do: value

  defp normalize_positive_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> int
      _ -> nil
    end
  end

  defp normalize_positive_int(_), do: nil

  defp normalize_optional_string(nil, _field), do: {:ok, nil}

  defp normalize_optional_string(value, _field) when is_binary(value) do
    trimmed = String.trim(value)
    {:ok, if(trimmed == "", do: nil, else: trimmed)}
  end

  defp normalize_optional_string(_value, field), do: {:error, "Invalid value for '#{field}'"}

  defp normalize_required_string(value, field) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: {:error, "Invalid value for '#{field}'"}, else: {:ok, trimmed}
  end

  defp normalize_required_string(_value, field), do: {:error, "Invalid value for '#{field}'"}

  defp normalize_path(nil), do: {:ok, "."}

  defp normalize_path(path) when is_binary(path) do
    trimmed = String.trim(path)
    if trimmed == "", do: {:ok, "."}, else: {:ok, trimmed}
  end

  defp normalize_path(_), do: {:error, "Invalid value for 'path'"}

  defp lookup_whitelist_key(mapping, key) when is_binary(key), do: Map.get(mapping, key)

  defp lookup_whitelist_key(mapping, key) when is_atom(key),
    do: Map.get(mapping, Atom.to_string(key))

  defp lookup_whitelist_key(_mapping, _key), do: nil

  defp safe_manager_call(fun) do
    {:ok, fun.()}
  catch
    :exit, {:timeout, _} ->
      {:error, :timeout}

    :exit, reason ->
      {:error, reason}
  end

  defp include_hidden?(params) when is_map(params) do
    case Map.get(params, "include_hidden") do
      value when value in [true, 1] ->
        true

      value when is_binary(value) ->
        String.downcase(String.trim(value)) in ["1", "true", "yes", "on"]

      _ ->
        false
    end
  end

  defp include_hidden?(_), do: false

  defp maybe_filter_hidden(projects, true), do: projects

  defp maybe_filter_hidden(projects, false) do
    Enum.filter(projects, fn project -> project.enabled != false end)
  end

  defp format_validation_errors(reasons) when is_list(reasons) do
    reasons
    |> Enum.map(fn
      {field, msg} -> "#{field} #{msg}"
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp stream_logs(conn, name) do
    Phoenix.PubSub.subscribe(Lantern.PubSub, "project:#{name}")

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    conn
    |> send_recent_logs(name)
    |> stream_logs_loop(name)
  end

  defp send_recent_logs(conn, name) do
    logs =
      try do
        ProcessRunner.get_logs(name)
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    Enum.reduce_while(logs, conn, fn line, acc ->
      case send_sse_chunk(acc, line) do
        {:ok, updated_conn} ->
          {:cont, updated_conn}

        {:error, :closed} ->
          {:halt, acc}

        {:error, reason} ->
          Logger.debug("Failed streaming historical log for #{name}: #{inspect(reason)}")
          {:halt, acc}
      end
    end)
  end

  defp stream_logs_loop(conn, name) do
    receive do
      {:log_line, ^name, line} ->
        case send_sse_chunk(conn, line) do
          {:ok, updated_conn} ->
            stream_logs_loop(updated_conn, name)

          {:error, :closed} ->
            conn

          {:error, reason} ->
            Logger.debug("Failed streaming log chunk for #{name}: #{inspect(reason)}")
            conn
        end
    after
      25_000 ->
        case chunk(conn, ": keepalive\n\n") do
          {:ok, updated_conn} -> stream_logs_loop(updated_conn, name)
          {:error, _reason} -> conn
        end
    end
  end

  defp send_sse_chunk(conn, line) do
    normalized_lines =
      line
      |> to_string()
      |> String.replace("\r", "")
      |> String.trim_trailing("\n")
      |> String.split("\n", trim: true)

    case normalized_lines do
      [] ->
        {:ok, conn}

      lines ->
        Enum.reduce_while(lines, {:ok, conn}, fn current_line, {:ok, acc} ->
          case chunk(acc, "data: #{current_line}\n\n") do
            {:ok, updated_conn} -> {:cont, {:ok, updated_conn}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
    end
  end
end
