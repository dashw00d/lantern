defmodule Lantern.Projects.Discovery do
  @moduledoc """
  Auto-discovers project docs and API endpoints.

  Discovery is optional and controlled via `docs_auto` and `api_auto`
  configuration in `lantern.yaml`.
  """

  alias Lantern.Projects.Project

  @default_docs_patterns [
    "README.md",
    "CHANGELOG.md",
    "AGENTS.md",
    "CLAUDE.md",
    "BRAIN.md",
    "SKILL.md",
    "docs/**/*.md"
  ]
  @default_docs_ignore [".git/**", "node_modules/**", "deps/**", "_build/**"]

  @default_api_candidates ["/openapi.json", "/swagger.json", "/docs/openapi.json"]
  @http_methods ~w(get post put patch delete options head trace)

  @doc """
  Returns updated project with discovery fields populated.
  """
  def enrich(%Project{} = project) do
    docs_result = discover_docs(project)
    api_result = discover_endpoints(project)

    %Project{
      project
      | discovered_docs: docs_result.docs,
        discovered_endpoints: api_result.endpoints,
        discovery: %{
          refreshed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          docs: %{
            enabled: docs_enabled?(project),
            count: length(docs_result.docs),
            source_count: length(docs_result.sources),
            sources: docs_result.sources
          },
          api: %{
            enabled: api_enabled?(project),
            count: length(api_result.endpoints),
            source_count: length(api_result.sources),
            sources: api_result.sources,
            errors: api_result.errors
          }
        }
    }
  end

  defp discover_docs(%Project{} = project) do
    if docs_enabled?(project) do
      config = project.docs_auto || %{}

      patterns =
        to_non_empty_list(config[:patterns] || config["patterns"], @default_docs_patterns)

      ignore_patterns =
        to_non_empty_list(config[:ignore] || config["ignore"], @default_docs_ignore)

      max_files = normalize_positive_int(config[:max_files] || config["max_files"], 100)
      max_bytes = normalize_positive_int(config[:max_bytes] || config["max_bytes"], 1_048_576)

      discovered_paths =
        patterns
        |> Enum.flat_map(fn pattern ->
          Path.wildcard(Path.join(project.path, pattern), match_dot: true)
        end)
        |> Enum.uniq()
        |> Enum.reject(&ignored_path?(&1, project.path, ignore_patterns))
        |> Enum.filter(&File.regular?/1)
        |> Enum.take(max_files)

      docs =
        discovered_paths
        |> Enum.map(fn full_path ->
          relative_path = Path.relative_to(full_path, project.path)
          size = file_size(full_path)

          if size <= max_bytes do
            %{
              path: relative_path,
              kind: infer_doc_kind(relative_path),
              source: "discovered",
              exists: true,
              size: size,
              mtime: file_mtime_iso(full_path)
            }
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      %{docs: docs, sources: patterns}
    else
      %{docs: [], sources: []}
    end
  end

  defp discover_endpoints(%Project{} = project) do
    if api_enabled?(project) do
      config = project.api_auto || %{}
      timeout_ms = normalize_positive_int(config[:timeout_ms] || config["timeout_ms"], 2_500)

      max_endpoints =
        normalize_positive_int(config[:max_endpoints] || config["max_endpoints"], 400)

      candidates =
        config
        |> resolve_api_sources(project)
        |> Enum.uniq()

      {endpoints, errors} =
        candidates
        |> Enum.reduce({[], []}, fn source, {acc_endpoints, acc_errors} ->
          case load_openapi_source(source, project.path, timeout_ms) do
            {:ok, %{"paths" => paths} = schema} when is_map(paths) ->
              parsed = parse_openapi_paths(paths, schema)
              {acc_endpoints ++ parsed, acc_errors}

            {:ok, _schema} ->
              {acc_endpoints, [%{source: source, error: "missing_paths"} | acc_errors]}

            {:error, reason} ->
              {acc_endpoints, [%{source: source, error: inspect(reason)} | acc_errors]}
          end
        end)

      normalized_endpoints =
        endpoints
        |> Enum.uniq_by(fn endpoint ->
          {String.upcase(endpoint.method), endpoint.path}
        end)
        |> Enum.take(max_endpoints)

      %{
        endpoints: normalized_endpoints,
        sources: candidates,
        errors: Enum.reverse(errors)
      }
    else
      %{endpoints: [], sources: [], errors: []}
    end
  end

  defp docs_enabled?(%Project{docs_auto: nil}), do: false

  defp docs_enabled?(%Project{docs_auto: config}) when is_map(config),
    do: truthy?(config[:enabled], true)

  defp docs_enabled?(_project), do: false

  defp api_enabled?(%Project{api_auto: nil}), do: false

  defp api_enabled?(%Project{api_auto: config}) when is_map(config),
    do: truthy?(config[:enabled], true)

  defp api_enabled?(_project), do: false

  defp resolve_api_sources(config, %Project{} = project) do
    sources = to_non_empty_list(config[:sources] || config["sources"], [])

    candidates =
      to_non_empty_list(config[:candidates] || config["candidates"], @default_api_candidates)

    base_urls =
      [project.upstream_url, project.base_url]
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    candidate_urls =
      for base_url <- base_urls,
          candidate <- candidates,
          is_binary(candidate),
          candidate != "" do
        join_url(base_url, candidate)
      end

    sources ++ candidate_urls
  end

  defp parse_openapi_paths(paths, schema) when is_map(paths) do
    Enum.flat_map(paths, fn {path, operations} ->
      if is_map(operations) do
        Enum.flat_map(operations, fn {method, op_data} ->
          method_down = method |> to_string() |> String.downcase()

          if method_down in @http_methods and is_map(op_data) do
            [
              %{
                method: String.upcase(method_down),
                path: path,
                description: op_data["summary"] || op_data["description"],
                category: first_tag(op_data["tags"]),
                risk: infer_risk(method_down, op_data),
                body_hint: body_hint(op_data, schema),
                source: "discovered"
              }
            ]
          else
            []
          end
        end)
      else
        []
      end
    end)
  end

  defp first_tag(tags) when is_list(tags), do: Enum.at(tags, 0)
  defp first_tag(_), do: nil

  defp infer_risk(method, op_data) do
    cond do
      Map.get(op_data, "x-risk") in ["low", "medium", "high", "critical"] ->
        Map.get(op_data, "x-risk")

      method in ["get", "head", "options"] ->
        "low"

      method in ["post", "put", "patch"] ->
        "medium"

      method == "delete" ->
        "high"

      true ->
        "unknown"
    end
  end

  defp body_hint(op_data, _schema) do
    case get_in(op_data, ["requestBody", "content"]) do
      content when is_map(content) ->
        content
        |> Map.keys()
        |> Enum.join(",")

      _ ->
        nil
    end
  end

  defp load_openapi_source(source, project_path, timeout_ms) when is_binary(source) do
    cond do
      String.starts_with?(source, "http://") or String.starts_with?(source, "https://") ->
        fetch_openapi_url(source, timeout_ms)

      true ->
        read_openapi_file(source, project_path)
    end
  end

  defp load_openapi_source(_source, _project_path, _timeout_ms), do: {:error, :invalid_source}

  defp fetch_openapi_url(url, timeout_ms) do
    request = Finch.build(:get, url)

    with {:ok, %Finch.Response{status: status, body: body}} <-
           Finch.request(request, Lantern.Finch,
             receive_timeout: timeout_ms,
             pool_timeout: timeout_ms
           ),
         true <- status in 200..299,
         {:ok, parsed} <- parse_openapi_payload(body) do
      {:ok, parsed}
    else
      false -> {:error, :http_error}
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp read_openapi_file(path, project_path) do
    full_path =
      if Path.type(path) == :absolute do
        path
      else
        Path.join(project_path, path)
      end

    with {:ok, content} <- File.read(full_path),
         {:ok, parsed} <- parse_openapi_payload(content) do
      {:ok, parsed}
    end
  end

  defp parse_openapi_payload(body) when is_map(body), do: {:ok, body}

  defp parse_openapi_payload(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} when is_map(parsed) ->
        {:ok, parsed}

      _ ->
        case YamlElixir.read_from_string(body) do
          {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
          _ -> {:error, :invalid_openapi_payload}
        end
    end
  end

  defp parse_openapi_payload(_), do: {:error, :invalid_openapi_payload}

  defp infer_doc_kind(path) when is_binary(path) do
    downcased = String.downcase(path)

    cond do
      String.contains?(downcased, "readme") -> "readme"
      String.contains?(downcased, "changelog") -> "changelog"
      String.contains?(downcased, "contributing") -> "contributing"
      String.contains?(downcased, "openapi") -> "openapi"
      String.ends_with?(downcased, ".md") -> "markdown"
      String.ends_with?(downcased, ".txt") -> "text"
      String.ends_with?(downcased, ".yaml") -> "yaml"
      String.ends_with?(downcased, ".yml") -> "yaml"
      String.ends_with?(downcased, ".json") -> "json"
      true -> "unknown"
    end
  end

  defp ignored_path?(full_path, project_path, ignore_patterns) do
    Enum.any?(ignore_patterns, fn pattern ->
      ignored_paths = Path.wildcard(Path.join(project_path, pattern), match_dot: true)
      full_path in ignored_paths
    end)
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp file_mtime_iso(path) do
    with {:ok, %{mtime: mtime}} <- File.stat(path, time: :posix),
         {:ok, dt} <- DateTime.from_unix(mtime) do
      DateTime.to_iso8601(dt)
    else
      _ -> nil
    end
  end

  defp to_non_empty_list(nil, fallback), do: fallback

  defp to_non_empty_list(value, _fallback) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp to_non_empty_list(value, _fallback) when is_binary(value) do
    value
    |> String.split(~r/[\n,]/, trim: true)
    |> to_non_empty_list([])
  end

  defp to_non_empty_list(_value, fallback), do: fallback

  defp normalize_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp normalize_positive_int(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp normalize_positive_int(_value, default), do: default

  defp truthy?(nil, default), do: default
  defp truthy?(value, _default) when value in [true, 1, "1"], do: true
  defp truthy?(value, _default) when value in [false, 0, "0"], do: false

  defp truthy?(value, default) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      v when v in ["true", "yes", "on"] -> true
      v when v in ["false", "no", "off"] -> false
      _ -> default
    end
  end

  defp truthy?(_value, default), do: default

  defp join_url(base_url, path) do
    base = String.trim_trailing(base_url, "/")
    suffix = if String.starts_with?(path, "/"), do: path, else: "/#{path}"
    base <> suffix
  end
end
