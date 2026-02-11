defmodule Lantern.Config.LanternYml do
  @moduledoc """
  Parser for lantern.yml files found in project roots.
  Supports variable interpolation and returns a map of project overrides.
  """

  alias Lantern.Projects.Project

  @supported_keys ~w(type domain root run routing features template)

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
    tld = Application.get_env(:lantern, :tld, ".test")

    base = %{
      name: name,
      path: path,
      domain: Map.get(yml_attrs, :domain, name <> tld),
      detection: %{confidence: :high, source: :config}
    }

    attrs =
      base
      |> maybe_put(:type, yml_attrs[:type])
      |> maybe_put(:root, yml_attrs[:root])
      |> maybe_put(:template, yml_attrs[:template])
      |> maybe_put(:features, yml_attrs[:features])
      |> maybe_put(:run_cmd, get_in(yml_attrs, [:run, :cmd]))
      |> maybe_put(:run_cwd, get_in(yml_attrs, [:run, :cwd]))
      |> maybe_put(:run_env, get_in(yml_attrs, [:run, :env]))

    Project.new(attrs)
  end

  # Private helpers

  defp normalize(yaml) do
    yaml
    |> Map.take(@supported_keys)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      atom_key = String.to_atom(key)
      Map.put(acc, atom_key, normalize_value(atom_key, value))
    end)
  end

  defp normalize_value(:type, value) when is_binary(value) do
    String.to_atom(value)
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
      websocket: value["websocket"] || false
    }
  end

  defp normalize_value(:features, value) when is_map(value) do
    Map.new(value, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp normalize_value(_key, value), do: value

  defp normalize_env(nil), do: %{}
  defp normalize_env(env) when is_map(env), do: env
  defp normalize_env(_), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
