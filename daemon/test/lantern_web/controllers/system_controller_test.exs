defmodule LanternWeb.SystemControllerTest do
  use LanternWeb.ConnCase

  alias Lantern.Projects.Manager

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

  describe "POST /api/system/shutdown" do
    test "deactivates running projects", %{conn: conn} do
      name = "shutdown-proj-#{System.unique_integer([:positive])}"

      path =
        Path.join(
          System.tmp_dir!(),
          "lantern-shutdown-proj-#{System.unique_integer([:positive])}"
        )

      marker = Path.join(path, ".stopped-by-shutdown")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "upstream_url" => "http://127.0.0.1:4777",
          "deploy" => %{"stop" => "touch .stopped-by-shutdown"}
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/activate")
      assert %{"data" => %{"status" => "running"}} = json_response(conn, 200)

      conn = post(conn, "/api/system/shutdown")
      assert %{"data" => %{"status" => status}} = json_response(conn, 200)
      assert status in ["ok", "partial"]

      conn = get(conn, "/api/projects/#{name}")
      assert %{"data" => %{"status" => "stopped"}} = json_response(conn, 200)
      assert File.exists?(marker)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end
end
