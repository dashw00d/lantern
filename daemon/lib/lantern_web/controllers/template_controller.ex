defmodule LanternWeb.TemplateController do
  use LanternWeb, :controller

  alias Lantern.Templates.{Registry, Template}

  def index(conn, _params) do
    templates = Registry.list()
    json(conn, %{data: Enum.map(templates, &Template.to_map/1)})
  end

  def create(conn, params) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      type: safe_to_atom(params["type"]),
      run_cmd: get_in(params, ["run", "cmd"]),
      run_cwd: get_in(params, ["run", "cwd"]),
      root: params["root"],
      features: atomize_features(params["features"] || %{})
    }

    case Registry.create(attrs) do
      {:ok, template} ->
        conn
        |> put_status(:created)
        |> json(%{data: Template.to_map(template)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "create_failed", message: inspect(reason)})
    end
  end

  def update(conn, %{"name" => name} = params) do
    attrs =
      params
      |> Map.drop(["name"])
      |> Enum.reduce(%{}, fn
        {"description", v}, acc -> Map.put(acc, :description, v)
        {"type", v}, acc -> Map.put(acc, :type, safe_to_atom(v))
        {"root", v}, acc -> Map.put(acc, :root, v)
        _, acc -> acc
      end)

    case Registry.update(name, attrs) do
      {:ok, template} ->
        json(conn, %{data: Template.to_map(template)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Template '#{name}' not found"})
    end
  end

  def delete(conn, %{"name" => name}) do
    case Registry.delete(name) do
      :ok ->
        json(conn, %{data: %{name: name, deleted: true}})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Template '#{name}' not found"})

      {:error, :cannot_delete_builtin} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "cannot_delete_builtin", message: "Cannot delete built-in templates"})
    end
  end

  defp safe_to_atom(nil), do: nil
  defp safe_to_atom(str) when is_binary(str), do: String.to_atom(str)

  defp atomize_features(features) when is_map(features) do
    Map.new(features, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp atomize_features(_), do: %{}
end
