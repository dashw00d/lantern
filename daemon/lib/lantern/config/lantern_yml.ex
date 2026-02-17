defmodule Lantern.Config.LanternYml do
  @moduledoc """
  Parser for lantern.yml/lantern.yaml files found in project roots.
  Supports variable interpolation and returns a map of project overrides.
  """

  alias Lantern.Projects.Project

  @supported_keys ~w(
    type domain root run routing features template
    id name description kind base_url upstream_url health_endpoint repo_url
    tags enabled deploy docs endpoints depends_on docs_auto api_auto
  )

  @supported_key_map Map.new(@supported_keys, fn key -> {key, String.to_atom(key)} end)

  @valid_types ~w(php proxy static unknown)
  @valid_kinds ~w(service project capability website tool)

  @feature_key_map %{
    "mailpit" => :mailpit,
    "auto_start" => :auto_start,
    "auto_open_browser" => :auto_open_browser
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

  @doc """
  Parses a lantern.yml file at the given path and returns project attributes.
  Returns {:ok, attrs} or {:error, reason}.
  """
  def parse(file_path) do
    case YamlElixir.read_from_file(file_path) do
      {:ok, yaml} when is_map(yaml) ->
        {:ok, normalize(yaml)}

      {:ok, _} ->
        {:error, "lantern.yml must contain a YAML mapping"}

      {:error, reason} ->
        {:error, "Failed to parse lantern.yml: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses a YAML string (useful for testing).
  """
  def parse_string(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, yaml} when is_map(yaml) ->
        {:ok, normalize(yaml)}

      {:ok, _} ->
        {:error, "lantern.yml must contain a YAML mapping"}

      {:error, reason} ->
        {:error, "Failed to parse YAML: #{inspect(reason)}"}
    end
  end

  @doc """
  Applies variable interpolation to a string.
  Supported variables: ${PORT}, ${DOMAIN}, ${NAME}, ${PATH}
  """
  def interpolate(nil, _vars), do: nil

  def interpolate(str, vars) when is_binary(str) do
    Enum.reduce(vars, str, fn {key, value}, acc ->
      String.replace(acc, "${#{key}}", to_string(value))
    end)
  end

  @doc """
  Builds a Project struct from a parsed lantern.yml and project metadata.
  """
  def to_project(yml_attrs, name, path) do
    tld = Application.get_env(:lantern, :tld, ".glow")

    base = %{
      name: name,
      path: path,
      domain: Map.get(yml_attrs, :domain, name <> tld),
      detection: %{confidence: :high, source: :config}
    }

    attrs =
      base
      |> maybe_put(:id, yml_attrs[:id])
      |> maybe_put(:type, yml_attrs[:type])
      |> maybe_put(:root, yml_attrs[:root])
      |> maybe_put(:template, yml_attrs[:template])
      |> maybe_put(:features, yml_attrs[:features])
      |> maybe_put(:run_cmd, get_in(yml_attrs, [:run, :cmd]))
      |> maybe_put(:run_cwd, get_in(yml_attrs, [:run, :cwd]))
      |> maybe_put(:run_env, get_in(yml_attrs, [:run, :env]))
      |> maybe_put(:description, yml_attrs[:description])
      |> maybe_put(:kind, yml_attrs[:kind])
      |> maybe_put(:base_url, yml_attrs[:base_url])
      |> maybe_put(:upstream_url, yml_attrs[:upstream_url])
      |> maybe_put(:health_endpoint, yml_attrs[:health_endpoint])
      |> maybe_put(:repo_url, yml_attrs[:repo_url])
      |> maybe_put(:tags, yml_attrs[:tags])
      |> maybe_put(:enabled, yml_attrs[:enabled])
      |> maybe_put(:deploy, yml_attrs[:deploy])
      |> maybe_put(:docs, yml_attrs[:docs])
      |> maybe_put(:endpoints, yml_attrs[:endpoints])
      |> maybe_put(:docs_auto, yml_attrs[:docs_auto])
      |> maybe_put(:api_auto, yml_attrs[:api_auto])
      |> maybe_put(:depends_on, yml_attrs[:depends_on])
      |> maybe_put(:routing, yml_attrs[:routing])

    Project.new(attrs)
  end

  # Private helpers

  defp normalize(yaml) do
    yaml
    |> Map.take(@supported_keys)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      atom_key = Map.fetch!(@supported_key_map, key)
      Map.put(acc, atom_key, normalize_value(atom_key, value))
    end)
  end

  defp normalize_value(:type, value) when is_binary(value) do
    normalized = String.trim(value)
    if normalized in @valid_types, do: String.to_existing_atom(normalized), else: :unknown
  end

  defp normalize_value(:kind, value) when is_binary(value) do
    normalized = String.trim(value)
    if normalized in @valid_kinds, do: String.to_existing_atom(normalized), else: :project
  end

  defp normalize_value(:run, value) when is_map(value) do
    %{
      cmd: value["cmd"],
      cwd: value["cwd"] || ".",
      env: normalize_env(value["env"]),
      pre_start: value["pre_start"],
      post_stop: value["post_stop"]
    }
  end

  defp normalize_value(:routing, value) when is_map(value) do
    %{
      aliases: value["aliases"] || [],
      paths: value["paths"] || %{},
      websocket: value["websocket"] || false,
      triggers: value["triggers"],
      risk: value["risk"],
      requires_confirmation: value["requires_confirmation"],
      max_concurrent: value["max_concurrent"],
      agents: value["agents"]
    }
  end

  defp normalize_value(:features, value) when is_map(value) do
    Map.new(value, fn {key, entry_value} ->
      case lookup_whitelist_key(@feature_key_map, key) do
        nil -> {to_string(key), entry_value}
        mapped_key -> {mapped_key, entry_value}
      end
    end)
  end

  defp normalize_value(:deploy, value) when is_map(value) do
    Map.new(value, fn {key, entry_value} ->
      case lookup_whitelist_key(@deploy_key_map, key) do
        nil -> {to_string(key), entry_value}
        mapped_key -> {mapped_key, entry_value}
      end
    end)
  end

  defp normalize_value(:upstream_url, value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_value(:docs, value) when is_list(value) do
    Enum.map(value, &normalize_doc_entry/1)
  end

  defp normalize_value(:endpoints, value) when is_list(value) do
    Enum.map(value, &normalize_endpoint_entry/1)
  end

  defp normalize_value(:docs_auto, value) when is_map(value) do
    %{
      enabled: normalize_bool(value["enabled"], true),
      patterns: normalize_string_list(value["patterns"]),
      ignore: normalize_string_list(value["ignore"]),
      max_files: normalize_int(value["max_files"]),
      max_bytes: normalize_int(value["max_bytes"])
    }
    |> reject_nil_values()
  end

  defp normalize_value(:api_auto, value) when is_map(value) do
    %{
      enabled: normalize_bool(value["enabled"], true),
      sources: normalize_string_list(value["sources"]),
      candidates: normalize_string_list(value["candidates"]),
      timeout_ms: normalize_int(value["timeout_ms"]),
      max_endpoints: normalize_int(value["max_endpoints"])
    }
    |> reject_nil_values()
  end

  defp normalize_value(:tags, value) when is_list(value), do: value
  defp normalize_value(:depends_on, value) when is_list(value), do: value

  defp normalize_value(_key, value), do: value

  defp normalize_doc_entry(entry) when is_binary(entry) do
    %{path: entry, kind: infer_doc_kind(entry)}
  end

  defp normalize_doc_entry(entry) when is_map(entry) do
    path = entry["path"] || entry[:path]

    %{
      path: path,
      kind: entry["kind"] || entry[:kind] || infer_doc_kind(path)
    }
  end

  defp normalize_doc_entry(entry), do: entry

  defp infer_doc_kind(nil), do: "unknown"

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

  defp normalize_endpoint_entry(entry) when is_map(entry) do
    Map.new(entry, fn {key, value} ->
      case lookup_whitelist_key(@endpoint_key_map, key) do
        nil -> {to_string(key), value}
        mapped_key -> {mapped_key, value}
      end
    end)
  end

  defp normalize_endpoint_entry(entry), do: entry

  defp normalize_string_list(nil), do: nil

  defp normalize_string_list(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_string_list(value) when is_binary(value) do
    value
    |> String.split(~r/[\n,]/, trim: true)
    |> normalize_string_list()
  end

  defp normalize_string_list(_), do: nil

  defp normalize_bool(nil, default), do: default
  defp normalize_bool(value, _default) when is_boolean(value), do: value
  defp normalize_bool(value, _default) when value in [1, "1"], do: true
  defp normalize_bool(value, _default) when value in [0, "0"], do: false

  defp normalize_bool(value, default) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      v when v in ["true", "yes", "on"] -> true
      v when v in ["false", "no", "off"] -> false
      _ -> default
    end
  end

  defp normalize_bool(_value, default), do: default

  defp normalize_int(nil), do: nil
  defp normalize_int(value) when is_integer(value), do: value

  defp normalize_int(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_int(_), do: nil

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env), do: env
  defp normalize_env(_), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp lookup_whitelist_key(mapping, key) when is_binary(key), do: Map.get(mapping, key)

  defp lookup_whitelist_key(mapping, key) when is_atom(key),
    do: Map.get(mapping, Atom.to_string(key))

  defp lookup_whitelist_key(_mapping, _key), do: nil
end
