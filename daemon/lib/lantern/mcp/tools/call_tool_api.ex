defmodule Lantern.MCP.Tools.CallToolAPI do
  @moduledoc "Call a registered tool's API endpoint through Lantern"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.MCP.Tools.Timeout
  alias Lantern.Projects.Manager

  @valid_methods ~w(GET POST PUT PATCH DELETE)

  schema do
    field(:tool, :string, required: true, description: "Tool name")
    field(:method, :string, description: "HTTP method (default: GET)")
    field(:path, :string, required: true, description: "API endpoint path (e.g. /browse)")
    field(:body, :string, description: "JSON request body")
  end

  def execute(%{tool: name, path: path} = params, frame) do
    Timeout.run(frame, 120_000, fn ->
      method = (params[:method] || "GET") |> String.upcase()

      with {:ok, tool} <- lookup_tool(name),
           {:ok, url} <- build_url(tool, path),
           :ok <- validate_method(method) do
        case do_request(method, url, params[:body]) do
          {:ok, body} ->
            {:reply, Response.tool() |> Response.text(body), frame}

          {:error, reason} ->
            {:error, Error.execution("Request failed: #{reason}"), frame}
        end
      else
        {:error, error} ->
          {:error, error, frame}
      end
    end)
  end

  defp lookup_tool(name) do
    case Manager.get(name) do
      nil -> {:error, Error.execution("'#{name}' not found")}
      project -> {:ok, project}
    end
  end

  defp build_url(tool, path) do
    base = tool.upstream_url || tool.base_url

    case base do
      nil -> {:error, Error.execution("'#{tool.name}' has no API endpoint")}
      url -> {:ok, String.trim_trailing(url, "/") <> path}
    end
  end

  defp validate_method(method) when method in @valid_methods, do: :ok
  defp validate_method(method), do: {:error, Error.execution("Invalid method: #{method}")}

  defp do_request(method, url, body) do
    method_atom = method |> String.downcase() |> String.to_existing_atom()

    headers =
      [{"accept", "application/json"}] ++
        if(body, do: [{"content-type", "application/json"}], else: [])

    request = Finch.build(method_atom, url, headers, body)

    case Finch.request(request, Lantern.Finch,
           pool_timeout: 5_000,
           receive_timeout: 90_000
         ) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status < 400 ->
        {:ok, resp_body}

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:error, "HTTP #{status}: #{resp_body}"}

      {:error, %Mint.TransportError{reason: reason}} ->
        {:error, "Connection failed: #{reason}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
