defmodule LanternWeb.LighthouseControllerTest do
  use LanternWeb.ConnCase

  alias Lantern.Projects.Manager

  describe "GET /:project/docs" do
    test "renders project docs index and serves doc content", %{conn: conn} do
      name = "lighthouse-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-lighthouse-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)
      File.write!(Path.join(path, "README.md"), "# Lighthouse Test\n")

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "kind" => "project",
          "docs" => [%{"path" => "README.md", "kind" => "readme"}]
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = get(conn, "/#{URI.encode_www_form(name)}/docs")
      assert html_response(conn, 200) =~ "#{name} docs"
      assert html_response(conn, 200) =~ "README.md"

      conn = get(conn, "/#{URI.encode_www_form(name)}/docs/README.md")
      assert response(conn, 200) =~ "Lighthouse Test"

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end
end
