defmodule LanternWeb.ToolControllerTest do
  use LanternWeb.ConnCase

  alias Lantern.Projects.Manager

  describe "GET /api/tools" do
    test "returns only available tool kinds by default", %{conn: conn} do
      service_name = "service-#{System.unique_integer([:positive])}"
      project_name = "project-#{System.unique_integer([:positive])}"
      hidden_name = "hidden-tool-#{System.unique_integer([:positive])}"

      service_path =
        Path.join(System.tmp_dir!(), "lantern-tool-service-#{System.unique_integer([:positive])}")

      project_path =
        Path.join(System.tmp_dir!(), "lantern-tool-project-#{System.unique_integer([:positive])}")

      hidden_path =
        Path.join(System.tmp_dir!(), "lantern-tool-hidden-#{System.unique_integer([:positive])}")

      File.mkdir_p!(service_path)
      File.mkdir_p!(project_path)
      File.mkdir_p!(hidden_path)

      conn =
        post(conn, "/api/projects", %{
          "name" => service_name,
          "path" => service_path,
          "kind" => "service"
        })

      assert %{"data" => %{"name" => ^service_name}} = json_response(conn, 201)

      conn =
        post(conn, "/api/projects", %{
          "name" => project_name,
          "path" => project_path,
          "kind" => "project"
        })

      assert %{"data" => %{"name" => ^project_name}} = json_response(conn, 201)

      conn =
        post(conn, "/api/projects", %{
          "name" => hidden_name,
          "path" => hidden_path,
          "kind" => "tool",
          "enabled" => false
        })

      assert %{"data" => %{"name" => ^hidden_name}} = json_response(conn, 201)

      conn = get(conn, "/api/tools")
      assert %{"data" => data, "tools" => tools_alias} = json_response(conn, 200)
      assert is_list(tools_alias)
      names = Enum.map(data, & &1["name"])

      assert service_name in names
      refute project_name in names
      refute hidden_name in names

      service = Enum.find(data, fn item -> item["name"] == service_name end)
      assert service
      assert service["health_status"] == "unknown"
      assert service["triggers"] == []
      assert service["agents"] == []
      assert service["risk"] == nil

      conn = get(conn, "/api/tools?include_hidden=true")
      assert %{"data" => hidden_data} = json_response(conn, 200)
      hidden_names = Enum.map(hidden_data, & &1["name"])
      assert hidden_name in hidden_names

      hidden = Enum.find(hidden_data, fn item -> item["name"] == hidden_name end)
      assert hidden
      assert hidden["health_status"] == "disabled"

      on_exit(fn ->
        Manager.deregister(service_name)
        Manager.deregister(project_name)
        Manager.deregister(hidden_name)
        File.rm_rf(service_path)
        File.rm_rf(project_path)
        File.rm_rf(hidden_path)
      end)
    end
  end

  describe "GET /api/tools/:id" do
    test "returns tool detail with routing and path aliases", %{conn: conn} do
      name = "detail-tool-#{System.unique_integer([:positive])}"
      path = Path.join(System.tmp_dir!(), "lantern-tool-detail-#{System.unique_integer([:positive])}")
      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "kind" => "tool",
          "docs" => [%{"path" => "README.md", "kind" => "readme"}],
          "routing" => %{
            "triggers" => ["scrape", "crawl"],
            "risk" => "medium",
            "agents" => ["main"]
          }
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = get(conn, "/api/tools/#{name}")
      assert %{"data" => data, "tool" => tool_alias} = json_response(conn, 200)
      assert tool_alias["id"] == data["id"]
      assert data["name"] == name
      assert data["triggers"] == ["scrape", "crawl"]
      assert data["risk"] == "medium"
      assert data["agents"] == ["main"]
      assert data["repo_path"] == path
      assert data["docs_paths"] == ["README.md"]

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "supports detail lookups when list is filtered to project kind", %{conn: conn} do
      name = "detail-project-kind-#{System.unique_integer([:positive])}"
      path = Path.join(System.tmp_dir!(), "lantern-tool-project-kind-#{System.unique_integer([:positive])}")
      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "kind" => "project"
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = get(conn, "/api/tools?kind=project")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, fn item -> item["name"] == name end)

      conn = get(conn, "/api/tools/#{name}?kind=project")
      assert %{"data" => %{"name" => ^name}} = json_response(conn, 200)

      conn = get(conn, "/api/tools/#{name}/docs?kind=project")
      assert %{"data" => %{"name" => ^name}} = json_response(conn, 200)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end

  describe "GET /api/tools/:id/docs" do
    test "returns project docs with content", %{conn: conn} do
      name = "docs-tool-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-tool-docs-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)
      File.write!(Path.join(path, "README.md"), "# Sample Tool\n")

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "kind" => "tool",
          "docs" => [%{"path" => "README.md", "kind" => "readme"}]
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = get(conn, "/api/tools/#{name}/docs")
      assert %{"data" => %{"name" => ^name, "id" => ^name, "tool_id" => ^name, "docs" => docs}} =
               json_response(conn, 200)

      assert Enum.any?(docs, fn doc ->
               doc["path"] == "README.md" and doc["content"] =~ "Sample Tool"
             end)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end
end
