defmodule LanternWeb.ServiceControllerTest do
  use LanternWeb.ConnCase

  describe "GET /api/services" do
    test "returns list of services", %{conn: conn} do
      conn = get(conn, "/api/services")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) > 0
      assert Enum.any?(data, fn s -> s["name"] == "mailpit" end)
    end
  end

  describe "GET /api/services/:name/status" do
    test "returns status for known service", %{conn: conn} do
      conn = get(conn, "/api/services/mailpit/status")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "mailpit"
    end

    test "returns 404 for unknown service", %{conn: conn} do
      conn = get(conn, "/api/services/unknown/status")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end
end
