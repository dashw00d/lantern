defmodule LanternWeb.HealthController do
  use LanternWeb, :controller

  alias Lantern.Health.Checker

  def index(conn, _params) do
    health = Checker.all()
    json(conn, %{data: health})
  end

  def show(conn, %{"name" => name}) do
    case Checker.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "No health data for project '#{name}'"})

      health ->
        json(conn, %{data: health})
    end
  end

  def check(conn, %{"name" => name}) do
    case Checker.check_now(name) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "not_found",
          message: "Project '#{name}' not found or not health-checkable"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "check_failed", message: inspect(reason)})
    end
  end
end
