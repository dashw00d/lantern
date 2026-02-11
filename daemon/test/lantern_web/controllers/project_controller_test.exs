defmodule LanternWeb.ProjectControllerTest do
  use LanternWeb.ConnCase

  describe "GET /api/projects" do
    test "returns empty list initially", %{conn: conn} do
      conn = get(conn, "/api/projects")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end
  end

  describe "POST /api/projects/scan" do
    test "scans workspace and returns projects", %{conn: conn} do
      conn = post(conn, "/api/projects/scan")
      assert %{"data" => data, "meta" => %{"count" => _count}} = json_response(conn, 200)
      assert is_list(data)
    end
  end

  describe "GET /api/projects/:name" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = get(conn, "/api/projects/nonexistent")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/projects/:name/activate" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = post(conn, "/api/projects/nonexistent/activate")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/projects/:name/deactivate" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = post(conn, "/api/projects/nonexistent/deactivate")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/projects/:name/restart" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = post(conn, "/api/projects/nonexistent/restart")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end
end
