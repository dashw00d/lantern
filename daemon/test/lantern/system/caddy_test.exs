defmodule Lantern.System.CaddyTest do
  use ExUnit.Case, async: true

  alias Lantern.System.Caddy
  alias Lantern.Projects.Project

  describe "generate_config/1" do
    test "generates PHP project config" do
      project =
        Project.new(%{
          name: "laravel-app",
          path: "/home/ryan/sites/laravel-app",
          domain: "laravel-app.glow",
          type: :php,
          root: "public"
        })

      config = Caddy.generate_config(project)
      assert config =~ "laravel-app.glow {"
      assert config =~ "root * /home/ryan/sites/laravel-app/public"
      assert config =~ "php_fastcgi unix/"
      assert config =~ "file_server"
    end

    test "generates proxy project config" do
      project =
        Project.new(%{
          name: "vite-app",
          path: "/home/ryan/sites/vite-app",
          domain: "vite-app.glow",
          type: :proxy,
          port: 41001
        })

      config = Caddy.generate_config(project)
      assert config =~ "vite-app.glow {"
      assert config =~ "reverse_proxy 127.0.0.1:41001"
    end

    test "generates static project config" do
      project =
        Project.new(%{
          name: "static-site",
          path: "/home/ryan/sites/static-site",
          domain: "static-site.glow",
          type: :static,
          root: "."
        })

      config = Caddy.generate_config(project)
      assert config =~ "static-site.glow {"
      assert config =~ "root * /home/ryan/sites/static-site/."
      assert config =~ "file_server"
    end

    test "returns error for unknown type" do
      project =
        Project.new(%{
          name: "unknown",
          path: "/home/ryan/sites/unknown",
          domain: "unknown.glow",
          type: :unknown
        })

      assert {:error, _} = Caddy.generate_config(project)
    end

    test "raises for proxy project without port" do
      project =
        Project.new(%{
          name: "no-port",
          path: "/home/ryan/sites/no-port",
          domain: "no-port.glow",
          type: :proxy,
          port: nil
        })

      assert_raise RuntimeError, fn ->
        Caddy.generate_config(project)
      end
    end
  end

  describe "generate_config_with_websocket/1" do
    test "includes WebSocket headers" do
      project =
        Project.new(%{
          name: "ws-app",
          path: "/home/ryan/sites/ws-app",
          domain: "ws-app.glow",
          type: :proxy,
          port: 41002
        })

      config = Caddy.generate_config_with_websocket(project)
      assert config =~ "ws-app.glow {"
      assert config =~ "reverse_proxy 127.0.0.1:41002"
      assert config =~ "header_up Upgrade"
      assert config =~ "header_up Connection"
    end
  end

  describe "base_caddyfile/0" do
    test "includes local_certs and import" do
      config = Caddy.base_caddyfile()
      assert config =~ "local_certs"
      assert config =~ "import /etc/caddy/sites.d/*.caddy"
    end
  end

  describe "config_path/1" do
    test "returns correct path" do
      assert Caddy.config_path("myapp") == "/etc/caddy/sites.d/myapp.caddy"
    end
  end
end
