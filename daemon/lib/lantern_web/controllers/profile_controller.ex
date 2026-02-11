defmodule LanternWeb.ProfileController do
  use LanternWeb, :controller

  alias Lantern.Profiles.{Manager, Profile}

  def index(conn, _params) do
    profiles = Manager.list()
    json(conn, %{data: Enum.map(profiles, &Profile.to_map/1)})
  end

  def activate(conn, %{"name" => name}) do
    case Manager.activate(name) do
      {:ok, profile} ->
        json(conn, %{data: Profile.to_map(profile), meta: %{activated: true}})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Profile '#{name}' not found"})
    end
  end
end
