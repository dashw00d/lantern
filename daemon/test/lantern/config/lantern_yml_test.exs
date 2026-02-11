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
  end
end
