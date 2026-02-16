defmodule Lantern.Projects.ProjectTest do
  use ExUnit.Case, async: true

  alias Lantern.Projects.Project

  describe "new/1" do
    test "creates a project with required fields" do
      project = Project.new(%{name: "myapp", path: "/home/ryan/sites/myapp"})
      assert project.name == "myapp"
      assert project.path == "/home/ryan/sites/myapp"
      assert project.status == :stopped
      assert project.type == :unknown
      assert project.run_env == %{}
      assert project.features == %{}
    end

    test "creates a project with all fields" do
      project =
        Project.new(%{
          name: "myapp",
          path: "/home/ryan/sites/myapp",
          domain: "myapp.glow",
          type: :proxy,
          port: 41001,
          run_cmd: "pnpm dev --port ${PORT}",
          run_cwd: ".",
          run_env: %{"NODE_ENV" => "development"},
          root: "public",
          features: %{mailpit: true},
          template: "vite"
        })

      assert project.type == :proxy
      assert project.port == 41001
      assert project.run_cmd == "pnpm dev --port ${PORT}"
      assert project.features == %{mailpit: true}
    end

    test "accepts keyword list" do
      project = Project.new(name: "myapp", path: "/home/ryan/sites/myapp")
      assert project.name == "myapp"
    end

    test "defaults id to name" do
      project = Project.new(%{name: "myapp", path: "/some/path"})
      assert project.id == "myapp"
    end

    test "allows custom id" do
      project = Project.new(%{name: "myapp", path: "/some/path", id: "my-custom-id"})
      assert project.id == "my-custom-id"
    end

    test "defaults kind to :project" do
      project = Project.new(%{name: "myapp", path: "/some/path"})
      assert project.kind == :project
    end

    test "sets registered_at automatically" do
      project = Project.new(%{name: "myapp", path: "/some/path"})
      assert project.registered_at != nil
      assert {:ok, _, _} = DateTime.from_iso8601(project.registered_at)
    end

    test "defaults new registry fields" do
      project = Project.new(%{name: "myapp", path: "/some/path"})
      assert project.tags == []
      assert project.enabled == true
      assert project.deploy == %{}
      assert project.docs == []
      assert project.endpoints == []
      assert project.depends_on == []
      assert project.description == nil
      assert project.base_url == nil
      assert project.health_endpoint == nil
      assert project.repo_url == nil
    end

    test "creates a project with registry fields" do
      project =
        Project.new(%{
          name: "ghost",
          path: "/home/ryan/sites/ghost",
          kind: :service,
          description: "Blog platform",
          base_url: "https://ghost.example.com",
          health_endpoint: "/ghost/api/v4/admin/site/",
          repo_url: "https://github.com/user/ghost",
          tags: ["blog", "cms"],
          deploy: %{start: "docker compose up -d", stop: "docker compose down"},
          docs: [%{path: "README.md", kind: "readme"}],
          endpoints: [
            %{method: "GET", path: "/ghost/api/v4/admin/site/", description: "Site info"}
          ],
          depends_on: ["mysql"]
        })

      assert project.kind == :service
      assert project.description == "Blog platform"
      assert project.base_url == "https://ghost.example.com"
      assert project.health_endpoint == "/ghost/api/v4/admin/site/"
      assert project.tags == ["blog", "cms"]
      assert project.deploy.start == "docker compose up -d"
      assert length(project.docs) == 1
      assert length(project.endpoints) == 1
      assert project.depends_on == ["mysql"]
    end
  end

  describe "validate/1" do
    test "validates a correct project" do
      project = Project.new(%{name: "myapp", path: "/home/ryan/sites/myapp", type: :proxy})
      assert {:ok, _} = Project.validate(project)
    end

    test "rejects empty name" do
      project = %Project{name: "", path: "/some/path"}
      assert {:error, errors} = Project.validate(project)
      assert Enum.any?(errors, fn {k, _} -> k == :name end)
    end

    test "rejects invalid type" do
      project = %Project{name: "myapp", path: "/some/path", type: :invalid}
      assert {:error, errors} = Project.validate(project)
      assert Enum.any?(errors, fn {k, _} -> k == :type end)
    end

    test "rejects invalid port" do
      project = %Project{name: "myapp", path: "/some/path", port: 99999}
      assert {:error, errors} = Project.validate(project)
      assert Enum.any?(errors, fn {k, _} -> k == :port end)
    end

    test "accepts nil port" do
      project = Project.new(%{name: "myapp", path: "/some/path", port: nil})
      assert {:ok, _} = Project.validate(project)
    end

    test "validates kind" do
      project = Project.new(%{name: "myapp", path: "/some/path", kind: :service})
      assert {:ok, _} = Project.validate(project)

      project = Project.new(%{name: "myapp", path: "/some/path", kind: :capability})
      assert {:ok, _} = Project.validate(project)

      project = Project.new(%{name: "myapp", path: "/some/path", kind: :tool})
      assert {:ok, _} = Project.validate(project)

      project = Project.new(%{name: "myapp", path: "/some/path", kind: :website})
      assert {:ok, _} = Project.validate(project)
    end

    test "rejects invalid kind" do
      project = %Project{name: "myapp", path: "/some/path", kind: :invalid}
      assert {:error, errors} = Project.validate(project)
      assert Enum.any?(errors, fn {k, _} -> k == :kind end)
    end

    test "validates upstream_url" do
      project =
        Project.new(%{name: "myapp", path: "/some/path", upstream_url: "https://example.com"})

      assert {:ok, _} = Project.validate(project)

      invalid =
        Project.new(%{name: "myapp", path: "/some/path", upstream_url: "ftp://example.com"})

      assert {:error, errors} = Project.validate(invalid)
      assert Enum.any?(errors, fn {k, _} -> k == :upstream_url end)
    end
  end

  describe "interpolate_cmd/2" do
    test "interpolates PORT and DOMAIN" do
      project =
        Project.new(%{
          name: "myapp",
          path: "/home/ryan/sites/myapp",
          port: 41001,
          domain: "myapp.glow"
        })

      result = Project.interpolate_cmd("pnpm dev --port ${PORT} --host ${DOMAIN}", project)
      assert result == "pnpm dev --port 41001 --host myapp.glow"
    end

    test "handles nil command" do
      project = Project.new(%{name: "myapp", path: "/some/path"})
      assert Project.interpolate_cmd(nil, project) == nil
    end
  end

  describe "to_map/1 and from_map/1" do
    test "round-trips through map" do
      project =
        Project.new(%{
          name: "myapp",
          path: "/home/ryan/sites/myapp",
          type: :proxy,
          port: 41001
        })

      map = Project.to_map(project)
      assert map.name == "myapp"
      assert map.type == :proxy
    end

    test "serializes new registry fields" do
      project =
        Project.new(%{
          name: "ghost",
          path: "/home/ryan/sites/ghost",
          kind: :service,
          description: "Blog platform",
          tags: ["blog"],
          deploy: %{start: "docker compose up -d"},
          depends_on: ["mysql"]
        })

      map = Project.to_map(project)
      assert map.id == "ghost"
      assert map.kind == :service
      assert map.description == "Blog platform"
      assert map.tags == ["blog"]
      assert map.deploy == %{start: "docker compose up -d"}
      assert map.depends_on == ["mysql"]
      assert map.enabled == true
    end

    test "from_map handles string keys safely" do
      map = %{
        "name" => "myapp",
        "path" => "/some/path",
        "type" => "proxy",
        "kind" => "service",
        "unknown_field" => "should be ignored"
      }

      project = Project.from_map(map)
      assert project.name == "myapp"
      assert project.type == :proxy
      assert project.kind == :service
    end

    test "from_map handles atom keys" do
      map = %{
        name: "myapp",
        path: "/some/path",
        type: :proxy,
        tags: ["web"],
        deploy: %{start: "npm start"}
      }

      project = Project.from_map(map)
      assert project.name == "myapp"
      assert project.tags == ["web"]
      assert project.deploy == %{start: "npm start"}
    end

    test "from_map does not atomize unknown keys or invalid enum values" do
      unknown_key = "unknown_key_#{System.unique_integer([:positive])}"
      unknown_type = "unknown_type_#{System.unique_integer([:positive])}"
      unknown_status = "unknown_status_#{System.unique_integer([:positive])}"
      unknown_kind = "unknown_kind_#{System.unique_integer([:positive])}"

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_type) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_status) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_kind) end

      project =
        Project.from_map(%{
          "name" => "myapp",
          "path" => "/some/path",
          "type" => unknown_type,
          "status" => unknown_status,
          "kind" => unknown_kind,
          unknown_key => "ignored"
        })

      assert project.type == :unknown
      assert project.status == :stopped
      assert project.kind == :project

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_type) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_status) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_kind) end
    end
  end
end
