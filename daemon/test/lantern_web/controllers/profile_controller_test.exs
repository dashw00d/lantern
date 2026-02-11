defmodule LanternWeb.ProfileControllerTest do
  use LanternWeb.ConnCase

  describe "GET /api/profiles" do
    test "returns list of profiles", %{conn: conn} do
      conn = get(conn, "/api/profiles")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert Enum.any?(data, fn p -> p["name"] == "light" end)
      assert Enum.any?(data, fn p -> p["name"] == "full_stack" end)
    end
  end

  describe "POST /api/profiles/:name/activate" do
    test "activates a known profile", %{conn: conn} do
      conn = post(conn, "/api/profiles/light/activate")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "light"
    end

    test "returns 404 for unknown profile", %{conn: conn} do
      conn = post(conn, "/api/profiles/nonexistent/activate")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end
end
