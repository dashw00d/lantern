defmodule LanternWeb.SystemControllerTest do
  use LanternWeb.ConnCase

  describe "GET /api/system/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, "/api/system/health")
      assert %{"data" => data} = json_response(conn, 200)

      assert Map.has_key?(data, "dns")
      assert Map.has_key?(data, "caddy")
      assert Map.has_key?(data, "tls")
      assert Map.has_key?(data, "daemon")

      for component <- ~w(dns caddy tls daemon) do
        assert %{"status" => _status, "message" => _message} = data[component]
      end
    end
  end

  describe "GET /api/system/settings" do
    test "returns settings", %{conn: conn} do
      conn = get(conn, "/api/system/settings")
      assert %{"data" => data} = json_response(conn, 200)
      assert Map.has_key?(data, "tld")
      assert Map.has_key?(data, "workspace_roots")
    end
  end
end
