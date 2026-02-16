defmodule Lantern.Config.LanternYmlTest do
  use ExUnit.Case, async: true

  alias Lantern.Config.LanternYml

  describe "parse_string/1" do
    test "parses a basic lantern.yml" do
      yaml = """
      type: proxy
      domain: myapp.glow
      root: public
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.type == :proxy
      assert attrs.domain == "myapp.glow"
      assert attrs.root == "public"
    end

    test "parses run configuration" do
      yaml = """
      type: proxy
      run:
        cmd: "pnpm dev --port ${PORT}"
        cwd: "."
        env:
          NODE_ENV: development
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.run.cmd == "pnpm dev --port ${PORT}"
      assert attrs.run.cwd == "."
      assert attrs.run.env == %{"NODE_ENV" => "development"}
    end

    test "parses features" do
      yaml = """
      type: proxy
      features:
        mailpit: true
        auto_start: false
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.features.mailpit == true
      assert attrs.features.auto_start == false
    end

    test "does not atomize arbitrary nested keys" do
      feature_key = "feature_#{System.unique_integer([:positive])}"
      deploy_key = "deploy_#{System.unique_integer([:positive])}"
      endpoint_key = "endpoint_#{System.unique_integer([:positive])}"

      assert_raise ArgumentError, fn -> String.to_existing_atom(feature_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(deploy_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(endpoint_key) end

      yaml = """
      type: proxy
      features:
        #{feature_key}: true
      deploy:
        #{deploy_key}: "echo hi"
      endpoints:
        - method: GET
          path: /health
          #{endpoint_key}: custom
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.features[feature_key] == true
      assert attrs.deploy[deploy_key] == "echo hi"
      first = Enum.at(attrs.endpoints, 0)
      assert first[endpoint_key] == "custom"

      assert_raise ArgumentError, fn -> String.to_existing_atom(feature_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(deploy_key) end
      assert_raise ArgumentError, fn -> String.to_existing_atom(endpoint_key) end
    end

    test "parses routing configuration" do
      yaml = """
      type: proxy
      routing:
        aliases:
          - myapp-alt.glow
        websocket: true
        paths:
          "/api": "127.0.0.1:8000"
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.routing.aliases == ["myapp-alt.glow"]
      assert attrs.routing.websocket == true
      assert attrs.routing.paths == %{"/api" => "127.0.0.1:8000"}
    end

    test "ignores unknown keys" do
      yaml = """
      type: proxy
      unknown_field: value
      another_unknown: 123
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.type == :proxy
      refute Map.has_key?(attrs, :unknown_field)
    end

    test "returns error for invalid YAML" do
      assert {:error, _} = LanternYml.parse_string("{{invalid yaml")
    end

    test "parses kind field" do
      yaml = """
      type: proxy
      kind: service
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.kind == :service
    end

    test "parses deploy configuration" do
      yaml = """
      type: proxy
      deploy:
        start: "docker compose up -d"
        stop: "docker compose down"
        restart: "docker compose restart"
        logs: "docker compose logs -f"
        status: "docker compose ps"
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.deploy.start == "docker compose up -d"
      assert attrs.deploy.stop == "docker compose down"
      assert attrs.deploy.restart == "docker compose restart"
      assert attrs.deploy.logs == "docker compose logs -f"
      assert attrs.deploy.status == "docker compose ps"
    end

    test "parses docs as list of strings" do
      yaml = """
      type: proxy
      docs:
        - README.md
        - CHANGELOG.md
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert length(attrs.docs) == 2
      assert Enum.at(attrs.docs, 0) == %{path: "README.md", kind: "readme"}
      assert Enum.at(attrs.docs, 1) == %{path: "CHANGELOG.md", kind: "changelog"}
    end

    test "parses docs as list of maps" do
      yaml = """
      type: proxy
      docs:
        - path: README.md
          kind: readme
        - path: docs/API.md
          kind: api
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert length(attrs.docs) == 2
      assert Enum.at(attrs.docs, 0) == %{path: "README.md", kind: "readme"}
      assert Enum.at(attrs.docs, 1) == %{path: "docs/API.md", kind: "api"}
    end

    test "parses endpoints" do
      yaml = """
      type: proxy
      endpoints:
        - method: GET
          path: /api/users
          description: List users
          category: users
          risk: low
        - method: POST
          path: /api/users
          description: Create user
          category: users
          risk: medium
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert length(attrs.endpoints) == 2
      first = Enum.at(attrs.endpoints, 0)
      assert first.method == "GET"
      assert first.path == "/api/users"
      assert first.description == "List users"
      assert first.risk == "low"
    end

    test "parses tags and depends_on" do
      yaml = """
      type: proxy
      tags:
        - blog
        - cms
        - typescript
      depends_on:
        - mysql
        - redis
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.tags == ["blog", "cms", "typescript"]
      assert attrs.depends_on == ["mysql", "redis"]
    end

    test "parses description and url fields" do
      yaml = """
      type: proxy
      description: "A blog platform"
      base_url: "https://ghost.example.com"
      health_endpoint: "/health"
      repo_url: "https://github.com/user/ghost"
      """

      assert {:ok, attrs} = LanternYml.parse_string(yaml)
      assert attrs.description == "A blog platform"
      assert attrs.base_url == "https://ghost.example.com"
      assert attrs.health_endpoint == "/health"
      assert attrs.repo_url == "https://github.com/user/ghost"
    end
  end

  describe "interpolate/2" do
    test "interpolates variables" do
      vars = %{"PORT" => 41001, "DOMAIN" => "myapp.glow"}
      result = LanternYml.interpolate("pnpm dev --port ${PORT} --host ${DOMAIN}", vars)
      assert result == "pnpm dev --port 41001 --host myapp.glow"
    end

    test "handles nil string" do
      assert LanternYml.interpolate(nil, %{}) == nil
    end
  end

  describe "to_project/3" do
    test "builds a project from yml attrs" do
      yml_attrs = %{
        type: :proxy,
        root: "public",
        run: %{cmd: "pnpm dev --port ${PORT}", cwd: ".", env: %{}},
        features: %{mailpit: true}
      }

      project = LanternYml.to_project(yml_attrs, "myapp", "/home/ryan/sites/myapp")
      assert project.name == "myapp"
      assert project.type == :proxy
      assert project.run_cmd == "pnpm dev --port ${PORT}"
      assert project.features == %{mailpit: true}
      assert project.detection.confidence == :high
      assert project.detection.source == :config
    end

    test "passes through new registry fields" do
      yml_attrs = %{
        type: :proxy,
        kind: :service,
        description: "Blog platform",
        base_url: "https://ghost.example.com",
        tags: ["blog"],
        deploy: %{start: "docker compose up -d"},
        docs: [%{path: "README.md", kind: "readme"}],
        depends_on: ["mysql"]
      }

      project = LanternYml.to_project(yml_attrs, "ghost", "/home/ryan/sites/ghost")
      assert project.kind == :service
      assert project.description == "Blog platform"
      assert project.base_url == "https://ghost.example.com"
      assert project.tags == ["blog"]
      assert project.deploy.start == "docker compose up -d"
      assert length(project.docs) == 1
      assert project.depends_on == ["mysql"]
    end
  end
end
