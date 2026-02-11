defmodule Lantern.Projects.Project do
  @moduledoc """
  Core project struct representing a detected or configured project.
  """

  @type project_type :: :php | :proxy | :static | :unknown
  @type project_status :: :stopped | :starting | :running | :stopping | :error | :needs_config
  @type confidence :: :high | :medium | :low

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
    status: :stopped,
    run_env: %{},
    features: %{},
    detection: %{confidence: :low, source: :auto}
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
          template: String.t() | nil
        }

  @valid_types [:php, :proxy, :static, :unknown]
  @valid_statuses [:stopped, :starting, :running, :stopping, :error, :needs_config]

  @doc """
  Creates a new project struct with sensible defaults.
  The domain defaults to `<name>.test` using the configured TLD.
  """
  def new(attrs) when is_map(attrs) do
    tld = Application.get_env(:lantern, :tld, ".test")
    %{name: _, path: _} = attrs
    name = attrs.name

    defaults = %{
      domain: name <> tld,
      type: :unknown,
      status: :stopped,
      run_env: %{},
      features: %{},
      detection: %{confidence: :low, source: :auto}
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
      template: project.template
    }
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

    new(attrs)
  end

  # Private validation helpers

  defp validate_name(errors, %{name: name}) when is_binary(name) and byte_size(name) > 0, do: errors
  defp validate_name(errors, _), do: [{:name, "must be a non-empty string"} | errors]

  defp validate_path(errors, %{path: path}) when is_binary(path) and byte_size(path) > 0, do: errors
  defp validate_path(errors, _), do: [{:path, "must be a non-empty string"} | errors]

  defp validate_type(errors, %{type: type}) when type in @valid_types, do: errors
  defp validate_type(errors, %{type: nil}), do: errors
  defp validate_type(errors, _), do: [{:type, "must be one of: #{inspect(@valid_types)}"} | errors]

  defp validate_status(errors, %{status: status}) when status in @valid_statuses, do: errors
  defp validate_status(errors, _), do: [{:status, "must be one of: #{inspect(@valid_statuses)}"} | errors]

  defp validate_port(errors, %{port: nil}), do: errors
  defp validate_port(errors, %{port: port}) when is_integer(port) and port > 0 and port < 65536, do: errors
  defp validate_port(errors, _), do: [{:port, "must be a valid port number (1-65535)"} | errors]

  defp normalize_keys(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} when is_atom(key) -> {key, value}
    end)
  rescue
    ArgumentError -> map
  end

  defp normalize_type(%{type: type} = attrs) when is_binary(type) do
    Map.put(attrs, :type, String.to_existing_atom(type))
  rescue
    ArgumentError -> attrs
  end

  defp normalize_type(attrs), do: attrs

  defp normalize_status(%{status: status} = attrs) when is_binary(status) do
    Map.put(attrs, :status, String.to_existing_atom(status))
  rescue
    ArgumentError -> attrs
  end

  defp normalize_status(attrs), do: attrs
end
