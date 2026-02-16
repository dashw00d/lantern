defmodule LanternWeb.RootControllerTest do
  use LanternWeb.ConnCase

  describe "GET /" do
    test "returns API discovery document", %{conn: conn} do
      conn = get(conn, "/")
      body = json_response(conn, 200)

      assert body["name"] == "lantern"
      assert is_binary(body["version"])
      assert is_binary(body["description"])
      assert is_map(body["endpoints"])
      assert body["endpoints"]["projects"] == "/api/projects"
      assert body["endpoints"]["tools"] == "/api/tools"
      assert body["endpoints"]["mcp"] == "/mcp"
    end
  end
end
