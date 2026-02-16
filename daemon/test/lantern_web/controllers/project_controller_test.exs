defmodule LanternWeb.ProjectControllerTest do
  use LanternWeb.ConnCase

  alias Lantern.Config.Settings
  alias Lantern.Projects.Manager

  describe "GET /api/projects" do
    test "returns empty list initially", %{conn: conn} do
      conn = get(conn, "/api/projects")
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "omits hidden projects by default and returns them when include_hidden=true", %{
      conn: conn
    } do
      name = "hidden-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-hidden-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "enabled" => false
        })

      assert %{"data" => %{"name" => ^name, "enabled" => false}} = json_response(conn, 201)

      conn = get(conn, "/api/projects")
      assert %{"data" => visible_data} = json_response(conn, 200)
      refute Enum.any?(visible_data, &(&1["name"] == name))

      conn = get(conn, "/api/projects?include_hidden=true")
      assert %{"data" => all_data} = json_response(conn, 200)
      assert Enum.any?(all_data, &(&1["name"] == name))

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end

  describe "POST /api/projects/scan" do
    test "scans workspace and returns projects", %{conn: conn} do
      conn = post(conn, "/api/projects/scan")
      assert %{"data" => data, "meta" => %{"count" => _count}} = json_response(conn, 200)
      assert is_list(data)
    end

    test "preserves registered projects outside workspace roots", %{conn: conn} do
      {scanned_name, scan_root} = seed_scannable_project!("scan-preserve")
      external_name = "external-#{System.unique_integer([:positive])}"

      external_path =
        Path.join(System.tmp_dir!(), "lantern-external-#{System.unique_integer([:positive])}")

      File.mkdir_p!(external_path)

      conn =
        post(conn, "/api/projects", %{
          "name" => external_name,
          "path" => external_path,
          "type" => "proxy",
          "kind" => "service"
        })

      assert %{"data" => %{"name" => ^external_name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/scan")
      assert %{"data" => data} = json_response(conn, 200)

      names = Enum.map(data, & &1["name"])
      assert scanned_name in names
      assert external_name in names

      on_exit(fn ->
        Manager.deregister(external_name)
        Manager.deregister(scanned_name)
        File.rm_rf(external_path)
        File.rm_rf(scan_root)
      end)
    end

    test "preserves manually registered projects inside workspace roots", %{conn: conn} do
      {scanned_name, scan_root} = seed_scannable_project!("scan-preserve-in-root")
      manual_name = "manual-in-root-#{System.unique_integer([:positive])}"
      manual_path = Path.join(scan_root, scanned_name)

      conn =
        post(conn, "/api/projects", %{
          "name" => manual_name,
          "path" => manual_path,
          "type" => "proxy",
          "kind" => "service"
        })

      assert %{"data" => %{"name" => ^manual_name, "path" => ^manual_path}} =
               json_response(conn, 201)

      conn = post(conn, "/api/projects/scan?include_hidden=true")
      assert %{"data" => data} = json_response(conn, 200)

      names = Enum.map(data, & &1["name"])
      assert scanned_name in names
      assert manual_name in names

      manual_entry = Enum.find(data, fn item -> item["name"] == manual_name end)
      assert manual_entry
      assert manual_entry["kind"] == "service"

      on_exit(fn ->
        Manager.deregister(manual_name)
        Manager.deregister(scanned_name)
        File.rm_rf(scan_root)
      end)
    end
  end

  describe "GET /api/projects/:name" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = get(conn, "/api/projects/nonexistent")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/projects/:name/logs" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = get(conn, "/api/projects/nonexistent/logs")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/projects/:name/dependencies and /dependents" do
    test "returns project-level dependency slices", %{conn: conn} do
      db_name = "dep-db-#{System.unique_integer([:positive])}"
      api_name = "dep-api-#{System.unique_integer([:positive])}"

      db_path =
        Path.join(System.tmp_dir!(), "lantern-dep-db-#{System.unique_integer([:positive])}")

      api_path =
        Path.join(System.tmp_dir!(), "lantern-dep-api-#{System.unique_integer([:positive])}")

      File.mkdir_p!(db_path)
      File.mkdir_p!(api_path)

      conn =
        post(conn, "/api/projects", %{
          "name" => db_name,
          "path" => db_path
        })

      assert %{"data" => %{"name" => ^db_name}} = json_response(conn, 201)

      conn =
        post(conn, "/api/projects", %{
          "name" => api_name,
          "path" => api_path,
          "depends_on" => [db_name]
        })

      assert %{"data" => %{"name" => ^api_name}} = json_response(conn, 201)

      conn = get(conn, "/api/projects/#{api_name}/dependencies")

      assert %{"data" => %{"project" => ^api_name, "depends_on" => [^db_name]}} =
               json_response(conn, 200)

      conn = get(conn, "/api/projects/#{db_name}/dependents")

      assert %{"data" => %{"project" => ^db_name, "depended_by" => depended_by}} =
               json_response(conn, 200)

      assert api_name in depended_by

      on_exit(fn ->
        Manager.deregister(api_name)
        Manager.deregister(db_name)
        File.rm_rf(api_path)
        File.rm_rf(db_path)
      end)
    end
  end

  describe "POST /api/projects/:name/reset" do
    test "reloads project fields from lantern manifest", %{conn: conn} do
      name = "manifest-reset-#{System.unique_integer([:positive])}"
      path = Path.join(System.tmp_dir!(), "lantern-reset-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "lantern.yaml"),
        """
        kind: service
        description: Manifest description
        run:
          cmd: npm run dev -- --port ${PORT}
          cwd: .
        tags:
          - alpha
          - beta
        """
      )

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "description" => "Edited description",
          "run_cmd" => "npm run custom",
          "tags" => ["edited"]
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn =
        patch(conn, "/api/projects/#{name}", %{
          "description" => "Edited again",
          "run_cmd" => "npm run edited",
          "tags" => ["edited", "manual"]
        })

      assert %{"data" => %{"description" => "Edited again"}} = json_response(conn, 200)

      conn = post(conn, "/api/projects/#{name}/reset", %{})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == name
      assert data["description"] == "Manifest description"
      assert data["run_cmd"] == "npm run dev -- --port ${PORT}"
      assert data["run_cwd"] == "."
      assert data["tags"] == ["alpha", "beta"]
      assert data["detection"]["source"] == "config"

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "returns 422 when no lantern manifest exists", %{conn: conn} do
      name = "manifest-missing-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-no-manifest-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/reset", %{})
      assert %{"error" => "manifest_not_found"} = json_response(conn, 422)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end

  describe "POST /api/projects/:name/activate" do
    test "returns 404 for nonexistent project", %{conn: conn} do
      conn = post(conn, "/api/projects/nonexistent/activate")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "rejects proxy run_cmd without dynamic PORT to avoid conflicts", %{conn: conn} do
      name = "port-conflict-#{System.unique_integer([:positive])}"

      path =
        Path.join(
          System.tmp_dir!(),
          "lantern-port-conflict-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "run_cmd" => "python -m http.server 8000"
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/activate")
      assert %{"error" => "activation_failed", "message" => message} = json_response(conn, 422)
      assert message =~ "run_cmd must use ${PORT}"

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "runs configured runtime start/stop commands on activate/deactivate", %{conn: conn} do
      name = "runtime-cmds-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-runtime-cmds-#{System.unique_integer([:positive])}")

      start_marker = Path.join(path, ".lantern-started")
      stop_marker = Path.join(path, ".lantern-stopped")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "upstream_url" => "http://127.0.0.1:4777",
          "deploy" => %{
            "start" => "touch .lantern-started",
            "stop" => "touch .lantern-stopped"
          }
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/activate")
      assert %{"data" => %{"name" => ^name, "status" => "running"}} = json_response(conn, 200)
      assert File.exists?(start_marker)

      conn = post(conn, "/api/projects/#{name}/deactivate")
      assert %{"data" => %{"name" => ^name, "status" => "stopped"}} = json_response(conn, 200)
      assert File.exists?(stop_marker)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "returns 422 when runtime process exits before binding assigned port", %{conn: conn} do
      name = "startup-fail-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-startup-fail-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "run_cmd" => "nonexistent_cmd_${PORT}"
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/activate")
      assert %{"error" => "activation_failed", "message" => message} = json_response(conn, 422)
      assert message =~ "runtime"

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "deactivate stops run_cmd listener for proxy project", %{conn: conn} do
      name = "runner-stop-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-runner-stop-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "run_cmd" => "python3 -m http.server ${PORT}"
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn = post(conn, "/api/projects/#{name}/activate")
      assert %{"data" => %{"status" => "running", "port" => port}} = json_response(conn, 200)
      assert is_integer(port)

      assert {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 250)
      :gen_tcp.close(socket)

      conn = post(conn, "/api/projects/#{name}/deactivate")
      assert %{"data" => %{"status" => "stopped", "port" => nil}} = json_response(conn, 200)

      assert_eventually_port_closed(port)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end

  defp assert_eventually_port_closed(port, remaining_attempts \\ 20)

  defp assert_eventually_port_closed(_port, 0) do
    flunk("expected listener to stop but port stayed open")
  end

  defp assert_eventually_port_closed(port, remaining_attempts) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)

        receive do
        after
          100 -> assert_eventually_port_closed(port, remaining_attempts - 1)
        end

      {:error, _reason} ->
        :ok
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

  describe "POST /api/projects" do
    test "accepts string enum values for type and kind", %{conn: conn} do
      name = "registered-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-register-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "proxy",
          "kind" => "service"
        })

      assert %{
               "data" => %{
                 "name" => ^name,
                 "type" => "proxy",
                 "kind" => "service"
               }
             } = json_response(conn, 201)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "returns 422 for invalid type", %{conn: conn} do
      name = "invalid-type-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-invalid-type-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path,
          "type" => "not-a-type"
        })

      assert %{"error" => "invalid_project", "message" => message} = json_response(conn, 422)
      assert message =~ "Invalid project type"

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end
  end

  describe "PUT /api/projects/:name" do
    test "updates run configuration for an existing project", %{conn: conn} do
      {project_name, _tmp_root} = seed_scannable_project!("update-proxy")

      conn = post(conn, "/api/projects/scan")
      assert %{"data" => _} = json_response(conn, 200)

      conn =
        put(conn, "/api/projects/#{project_name}", %{
          "run_cmd" => "npm run dev -- --port ${PORT}",
          "run_cwd" => "."
        })

      assert %{
               "data" => %{
                 "name" => ^project_name,
                 "run_cmd" => "npm run dev -- --port ${PORT}",
                 "run_cwd" => "."
               }
             } = json_response(conn, 200)
    end

    test "returns 422 for invalid project type", %{conn: conn} do
      {project_name, _tmp_root} = seed_scannable_project!("invalid-type")

      conn = post(conn, "/api/projects/scan")
      assert %{"data" => _} = json_response(conn, 200)

      conn = put(conn, "/api/projects/#{project_name}", %{"type" => "not-a-type"})

      assert %{"error" => "invalid_update"} = json_response(conn, 422)
    end

    test "patch accepts string enum values for type and kind", %{conn: conn} do
      name = "patch-enum-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-patch-enum-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn =
        patch(conn, "/api/projects/#{name}", %{
          "type" => "proxy",
          "kind" => "tool"
        })

      assert %{"data" => %{"type" => "proxy", "kind" => "tool"}} = json_response(conn, 200)

      on_exit(fn ->
        Manager.deregister(name)
        File.rm_rf(path)
      end)
    end

    test "patch supports renaming and path updates", %{conn: conn} do
      name = "rename-src-#{System.unique_integer([:positive])}"
      new_name = "rename-dst-#{System.unique_integer([:positive])}"

      path =
        Path.join(System.tmp_dir!(), "lantern-rename-src-#{System.unique_integer([:positive])}")

      new_path =
        Path.join(System.tmp_dir!(), "lantern-rename-dst-#{System.unique_integer([:positive])}")

      File.mkdir_p!(path)
      File.mkdir_p!(new_path)

      conn =
        post(conn, "/api/projects", %{
          "name" => name,
          "path" => path
        })

      assert %{"data" => %{"name" => ^name}} = json_response(conn, 201)

      conn =
        patch(conn, "/api/projects/#{name}", %{
          "new_name" => new_name,
          "path" => new_path
        })

      assert %{"data" => %{"name" => ^new_name, "path" => ^new_path}} = json_response(conn, 200)

      conn = get(conn, "/api/projects/#{new_name}")
      assert %{"data" => %{"name" => ^new_name}} = json_response(conn, 200)

      conn = get(conn, "/api/projects/#{name}")
      assert %{"error" => "not_found"} = json_response(conn, 404)

      on_exit(fn ->
        Manager.deregister(new_name)
        File.rm_rf(path)
        File.rm_rf(new_path)
      end)
    end
  end

  defp seed_scannable_project!(suffix) do
    previous_roots = Settings.get(:workspace_roots)

    tmp_root =
      Path.join(
        System.tmp_dir!(),
        "lantern-project-controller-#{System.unique_integer([:positive])}"
      )

    project_name = "sample-#{suffix}"
    project_path = Path.join(tmp_root, project_name)

    File.mkdir_p!(project_path)

    File.write!(
      Path.join(project_path, "lantern.yaml"),
      """
      name: #{project_name}
      kind: service
      type: proxy
      run:
        cmd: npm run dev -- --port ${PORT}
      """
    )

    :ok = Settings.update(%{workspace_roots: [tmp_root]})

    on_exit(fn ->
      :ok = Settings.update(%{workspace_roots: previous_roots})
      File.rm_rf(tmp_root)
    end)

    {project_name, tmp_root}
  end
end
