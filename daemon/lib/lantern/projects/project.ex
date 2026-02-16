defmodule Lantern.Projects.Project do
  @moduledoc """
  Core project struct representing a detected or configured project.
  """

  @type project_type :: :php | :proxy | :static | :unknown
  @type project_status :: :stopped | :starting | :running | :stopping | :error | :needs_config
  @type confidence :: :high | :medium | :low
  @type project_kind :: :service | :project | :capability | :website | :tool

  @enforce_keys [:name, :path]
  defstruct [
    :name,
    :path,
    :domain,
    :type,
    :port,
    :run_cmd,
    :run_cwd,
    :root,
    :pid,
    :template,
    # New registry fields
    :id,
    :description,
    :base_url,
    :upstream_url,
    :health_endpoint,
    :repo_url,
    :registered_at,
    kind: :project,
    status: :stopped,
    run_env: %{},
    features: %{},
    detection: %{confidence: :low, source: :auto},
    tags: [],
    enabled: true,
    deploy: %{},
    docs: [],
    endpoints: [],
    docs_auto: %{},
    api_auto: %{},
    discovered_docs: [],
    discovered_endpoints: [],
    discovery: %{},
    routing: nil,
    depends_on: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          domain: String.t() | nil,
          type: project_type() | nil,
          status: project_status(),
          port: non_neg_integer() | nil,
          run_cmd: String.t() | nil,
          run_cwd: String.t() | nil,
          run_env: map(),
          root: String.t() | nil,
          features: map(),
          detection: map(),
          pid: non_neg_integer() | nil,
          template: String.t() | nil,
          id: String.t() | nil,
          description: String.t() | nil,
          kind: project_kind(),
          base_url: String.t() | nil,
          upstream_url: String.t() | nil,
          health_endpoint: String.t() | nil,
          repo_url: String.t() | nil,
          tags: [String.t()],
          enabled: boolean(),
          registered_at: String.t() | nil,
          deploy: map(),
          docs: [map()],
          endpoints: [map()],
          docs_auto: map(),
          api_auto: map(),
          discovered_docs: [map()],
          discovered_endpoints: [map()],
          discovery: map(),
          routing: map() | nil,
          depends_on: [String.t()]
        }

  @valid_types [:php, :proxy, :static, :unknown]
  @valid_statuses [:stopped, :starting, :running, :stopping, :error, :needs_config]
  @valid_kinds [:service, :project, :capability, :website, :tool]

  @known_keys ~w(
    name path domain type status port run_cmd run_cwd run_env root features
    detection pid template id description kind base_url upstream_url health_endpoint
    repo_url tags enabled registered_at deploy docs endpoints docs_auto api_auto
    discovered_docs discovered_endpoints discovery routing depends_on
  )a

  @known_key_map Map.new(@known_keys, fn key -> {Atom.to_string(key), key} end)
  @valid_type_map Map.new(@valid_types, fn type -> {Atom.to_string(type), type} end)
  @valid_status_map Map.new(@valid_statuses, fn status -> {Atom.to_string(status), status} end)
  @valid_kind_map Map.new(@valid_kinds, fn kind -> {Atom.to_string(kind), kind} end)

  @doc """
  Creates a new project struct with sensible defaults.
  The domain defaults to `<name>.glow` using the configured TLD.
  """
  def new(attrs) when is_map(attrs) do
    tld = Application.get_env(:lantern, :tld, ".glow")
    %{name: _, path: _} = attrs
    name = attrs.name

    defaults = %{
      id: Map.get(attrs, :id) || name,
      domain: name <> tld,
      type: :unknown,
      status: :stopped,
      run_env: %{},
      features: %{},
      detection: %{confidence: :low, source: :auto},
      registered_at: Map.get(attrs, :registered_at) || DateTime.utc_now() |> DateTime.to_iso8601()
    }

    struct!(__MODULE__, Map.merge(defaults, attrs))
  end

  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  @doc """
  Validates a project struct, returning {:ok, project} or {:error, reasons}.
  """
  def validate(%__MODULE__{} = project) do
    errors =
      []
      |> validate_name(project)
      |> validate_path(project)
      |> validate_type(project)
      |> validate_status(project)
      |> validate_port(project)
      |> validate_upstream_url(project)
      |> validate_kind(project)

    case errors do
      [] -> {:ok, project}
      errors -> {:error, errors}
    end
  end

  @doc """
  Interpolates variables in a command string.
  Supported: ${PORT}, ${DOMAIN}, ${NAME}, ${PATH}
  """
  def interpolate_cmd(nil, _project), do: nil

  def interpolate_cmd(cmd, %__MODULE__{} = project) do
    cmd
    |> String.replace("${PORT}", to_string(project.port || ""))
    |> String.replace("${DOMAIN}", project.domain || "")
    |> String.replace("${NAME}", project.name)
    |> String.replace("${PATH}", project.path)
  end

  @doc """
  Converts a project struct to a map suitable for JSON serialization.
  """
  def to_map(%__MODULE__{} = project) do
    %{
      name: project.name,
      path: project.path,
      domain: project.domain,
      type: project.type,
      status: project.status,
      port: project.port,
      run_cmd: project.run_cmd,
      run_cwd: project.run_cwd,
      run_env: project.run_env,
      root: project.root,
      features: project.features,
      detection: project.detection,
      pid: project.pid,
      template: project.template,
      id: project.id,
      description: project.description,
      kind: project.kind,
      base_url: project.base_url,
      upstream_url: project.upstream_url,
      health_endpoint: project.health_endpoint,
      repo_url: project.repo_url,
      tags: project.tags,
      enabled: project.enabled,
      registered_at: project.registered_at,
      deploy: project.deploy,
      docs: project.docs,
      endpoints: project.endpoints,
      docs_auto: project.docs_auto,
      api_auto: project.api_auto,
      discovered_docs: project.discovered_docs,
      discovered_endpoints: project.discovered_endpoints,
      docs_available: merged_docs(project),
      endpoints_available: merged_endpoints(project),
      discovery: project.discovery,
      routing: project.routing,
      depends_on: project.depends_on
    }
  end

  @doc """
  Returns merged docs where manual entries win over discovered ones.
  """
  def merged_docs(%__MODULE__{} = project) do
    manual_docs =
      project.docs
      |> List.wrap()
      |> Enum.map(fn doc ->
        doc
        |> normalize_doc()
        |> Map.put_new(:source, "manual")
      end)

    discovered_docs =
      project.discovered_docs
      |> List.wrap()
      |> Enum.map(fn doc ->
        doc
        |> normalize_doc()
        |> Map.put_new(:source, "discovered")
      end)

    manual_paths =
      manual_docs
      |> Enum.map(&Map.get(&1, :path))
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    manual_docs ++
      Enum.reject(discovered_docs, fn doc -> MapSet.member?(manual_paths, doc.path) end)
  end

  @doc """
  Returns merged endpoints where manual entries win over discovered ones.
  """
  def merged_endpoints(%__MODULE__{} = project) do
    manual_endpoints =
      project.endpoints
      |> List.wrap()
      |> Enum.map(fn endpoint ->
        endpoint
        |> normalize_endpoint()
        |> Map.put_new(:source, "manual")
      end)

    discovered_endpoints =
      project.discovered_endpoints
      |> List.wrap()
      |> Enum.map(fn endpoint ->
        endpoint
        |> normalize_endpoint()
        |> Map.put_new(:source, "discovered")
      end)

    manual_pairs =
      manual_endpoints
      |> Enum.map(&endpoint_signature/1)
      |> MapSet.new()

    manual_endpoints ++
      Enum.reject(discovered_endpoints, fn endpoint ->
        MapSet.member?(manual_pairs, endpoint_signature(endpoint))
      end)
  end

  @doc """
  Creates a project struct from a map (e.g. loaded from state store).
  String keys are converted to atoms for known fields.
  """
  def from_map(map) when is_map(map) do
    attrs =
      map
      |> normalize_keys()
      |> normalize_type()
      |> normalize_status()
      |> normalize_kind()

    new(attrs)
  end

  # Private validation helpers

  defp validate_name(errors, %{name: name}) when is_binary(name) and byte_size(name) > 0,
    do: errors

  defp validate_name(errors, _), do: [{:name, "must be a non-empty string"} | errors]

  defp validate_path(errors, %{path: path}) when is_binary(path) and byte_size(path) > 0,
    do: errors

  defp validate_path(errors, _), do: [{:path, "must be a non-empty string"} | errors]

  defp validate_type(errors, %{type: type}) when type in @valid_types, do: errors
  defp validate_type(errors, %{type: nil}), do: errors

  defp validate_type(errors, _),
    do: [{:type, "must be one of: #{inspect(@valid_types)}"} | errors]

  defp validate_status(errors, %{status: status}) when status in @valid_statuses, do: errors

  defp validate_status(errors, _),
    do: [{:status, "must be one of: #{inspect(@valid_statuses)}"} | errors]

  defp validate_port(errors, %{port: nil}), do: errors

  defp validate_port(errors, %{port: port}) when is_integer(port) and port > 0 and port < 65536,
    do: errors

  defp validate_port(errors, _), do: [{:port, "must be a valid port number (1-65535)"} | errors]

  defp validate_upstream_url(errors, %{upstream_url: nil}), do: errors

  defp validate_upstream_url(errors, %{upstream_url: upstream_url})
       when is_binary(upstream_url) do
    normalized = String.trim(upstream_url)

    case URI.parse(normalized) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and byte_size(host) > 0 ->
        errors

      _ ->
        [{:upstream_url, "must be a valid http(s) URL"} | errors]
    end
  end

  defp validate_upstream_url(errors, _),
    do: [{:upstream_url, "must be a valid http(s) URL"} | errors]

  defp validate_kind(errors, %{kind: kind}) when kind in @valid_kinds, do: errors
  defp validate_kind(errors, %{kind: nil}), do: errors

  defp validate_kind(errors, _),
    do: [{:kind, "must be one of: #{inspect(@valid_kinds)}"} | errors]

  defp normalize_keys(map) do
    map
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_binary(key) ->
        case safe_to_atom(key) do
          nil -> acc
          atom_key -> Map.put(acc, atom_key, value)
        end

      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      _, acc ->
        acc
    end)
  end

  defp safe_to_atom(key) when is_binary(key) do
    Map.get(@known_key_map, key)
  end

  defp normalize_type(%{type: type} = attrs) when is_binary(type) do
    case safe_to_type_atom(type) do
      nil -> Map.delete(attrs, :type)
      atom -> Map.put(attrs, :type, atom)
    end
  end

  defp normalize_type(attrs), do: attrs

  defp normalize_status(%{status: status} = attrs) when is_binary(status) do
    case safe_to_status_atom(status) do
      nil -> Map.delete(attrs, :status)
      atom -> Map.put(attrs, :status, atom)
    end
  end

  defp normalize_status(attrs), do: attrs

  defp normalize_kind(%{kind: kind} = attrs) when is_binary(kind) do
    case safe_to_kind_atom(kind) do
      nil -> Map.delete(attrs, :kind)
      atom -> Map.put(attrs, :kind, atom)
    end
  end

  defp normalize_kind(attrs), do: attrs

  defp safe_to_type_atom(str) do
    Map.get(@valid_type_map, str)
  end

  defp safe_to_status_atom(str) do
    Map.get(@valid_status_map, str)
  end

  defp safe_to_kind_atom(str) do
    Map.get(@valid_kind_map, str)
  end

  defp normalize_doc(doc) when is_map(doc) do
    path = map_value(doc, "path", :path)
    kind = map_value(doc, "kind", :kind) || "unknown"

    %{
      path: path,
      kind: kind
    }
    |> maybe_put(:source, map_value(doc, "source", :source))
    |> maybe_put(:exists, map_value(doc, "exists", :exists))
    |> maybe_put(:size, map_value(doc, "size", :size))
    |> maybe_put(:mtime, map_value(doc, "mtime", :mtime))
  end

  defp normalize_doc(other), do: %{path: to_string(other), kind: "unknown"}

  defp normalize_endpoint(endpoint) when is_map(endpoint) do
    method = map_value(endpoint, "method", :method)
    path = map_value(endpoint, "path", :path)

    %{
      method: method,
      path: path
    }
    |> maybe_put(:description, map_value(endpoint, "description", :description))
    |> maybe_put(:category, map_value(endpoint, "category", :category))
    |> maybe_put(:risk, map_value(endpoint, "risk", :risk))
    |> maybe_put(:body_hint, map_value(endpoint, "body_hint", :body_hint))
    |> maybe_put(:params, map_value(endpoint, "params", :params))
    |> maybe_put(:source, map_value(endpoint, "source", :source))
  end

  defp normalize_endpoint(other), do: %{method: "GET", path: to_string(other)}

  defp endpoint_signature(endpoint) do
    method = endpoint.method |> to_string() |> String.upcase() |> String.trim()
    path = endpoint.path |> to_string() |> String.trim()
    {method, path}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp map_value(map, string_key, atom_key) do
    case Map.fetch(map, string_key) do
      {:ok, value} -> value
      :error -> Map.get(map, atom_key)
    end
  end
end
