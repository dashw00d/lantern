defmodule LanternWeb.TemplateControllerTest do
  use LanternWeb.ConnCase

  describe "GET /api/templates" do
    test "returns list of templates", %{conn: conn} do
      conn = get(conn, "/api/templates")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert Enum.any?(data, fn t -> t["name"] == "laravel" end)
      assert Enum.any?(data, fn t -> t["name"] == "vite" end)
      assert Enum.any?(data, fn t -> t["name"] == "nextjs" end)
    end
  end
end
