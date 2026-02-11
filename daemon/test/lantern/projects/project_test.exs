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
          domain: "myapp.test",
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
  end

  describe "interpolate_cmd/2" do
    test "interpolates PORT and DOMAIN" do
      project = Project.new(%{name: "myapp", path: "/home/ryan/sites/myapp", port: 41001, domain: "myapp.test"})
      result = Project.interpolate_cmd("pnpm dev --port ${PORT} --host ${DOMAIN}", project)
      assert result == "pnpm dev --port 41001 --host myapp.test"
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
  end
end
