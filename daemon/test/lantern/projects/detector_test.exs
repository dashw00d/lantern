defmodule Lantern.Projects.DetectorTest do
  use ExUnit.Case, async: true

  alias Lantern.Projects.Detector

  setup do
    # Create a temporary directory for mock projects
    tmp_dir = Path.join(System.tmp_dir!(), "lantern_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_cleanup(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  defp on_cleanup(fun) do
    ExUnit.Callbacks.on_exit(fun)
  end

  describe "detect/1" do
    test "detects Laravel project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "laravel-app")
      File.mkdir_p!(Path.join(project_dir, "public"))
      File.write!(Path.join(project_dir, "artisan"), "#!/usr/bin/env php")
      File.write!(Path.join(project_dir, "public/index.php"), "<?php")

      project = Detector.detect(project_dir)
      assert project.type == :php
      assert project.root == "public"
      assert project.detection.confidence == :high
      assert project.detection.framework == "laravel"
    end

    test "detects Symfony project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "symfony-app")
      File.mkdir_p!(Path.join(project_dir, "bin"))
      File.mkdir_p!(Path.join(project_dir, "public"))
      File.write!(Path.join(project_dir, "bin/console"), "#!/usr/bin/env php")
      File.write!(Path.join(project_dir, "public/index.php"), "<?php")

      project = Detector.detect(project_dir)
      assert project.type == :php
      assert project.detection.framework == "symfony"
    end

    test "detects Next.js project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "nextjs-app")
      File.mkdir_p!(project_dir)
      pkg = Jason.encode!(%{dependencies: %{"next" => "14.0.0", "react" => "18.0.0"}})
      File.write!(Path.join(project_dir, "package.json"), pkg)

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "nextjs"
      assert project.run_cmd =~ "next dev"
      assert project.run_cmd =~ "${PORT}"
    end

    test "detects Vite project with pnpm", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "vite-app")
      File.mkdir_p!(project_dir)
      pkg = Jason.encode!(%{devDependencies: %{"vite" => "5.0.0"}})
      File.write!(Path.join(project_dir, "package.json"), pkg)
      File.write!(Path.join(project_dir, "pnpm-lock.yaml"), "lockfileVersion: 6")

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "vite"
      assert project.run_cmd =~ "pnpm exec vite"
      assert project.detection.package_manager == :pnpm
    end

    test "detects Nuxt project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "nuxt-app")
      File.mkdir_p!(project_dir)
      pkg = Jason.encode!(%{devDependencies: %{"nuxt" => "3.0.0"}})
      File.write!(Path.join(project_dir, "package.json"), pkg)

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "nuxt"
    end

    test "detects Remix project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "remix-app")
      File.mkdir_p!(project_dir)
      pkg = Jason.encode!(%{devDependencies: %{"@remix-run/dev" => "2.0.0"}})
      File.write!(Path.join(project_dir, "package.json"), pkg)

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "remix"
    end

    test "detects Django project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "django-app")
      File.mkdir_p!(project_dir)
      File.write!(Path.join(project_dir, "manage.py"), "#!/usr/bin/env python")

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "django"
      assert project.run_cmd =~ "manage.py runserver"
    end

    test "detects FastAPI project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "fastapi-app")
      File.mkdir_p!(project_dir)
      File.write!(Path.join(project_dir, "pyproject.toml"), """
      [project]
      dependencies = ["fastapi>=0.100.0", "uvicorn"]
      """)

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "fastapi"
      assert project.run_cmd =~ "uvicorn"
    end

    test "detects Flask project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "flask-app")
      File.mkdir_p!(project_dir)
      File.write!(Path.join(project_dir, "app.py"), "from flask import Flask\napp = Flask(__name__)")

      project = Detector.detect(project_dir)
      assert project.type == :proxy
      assert project.detection.framework == "flask"
    end

    test "detects static site", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "static-site")
      File.mkdir_p!(project_dir)
      File.write!(Path.join(project_dir, "index.html"), "<html></html>")

      project = Detector.detect(project_dir)
      assert project.type == :static
      assert project.detection.framework == "static"
    end

    test "returns unknown for empty project", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "empty-project")
      File.mkdir_p!(project_dir)

      project = Detector.detect(project_dir)
      assert project.type == :unknown
      assert project.detection.confidence == :low
    end

    test "prefers lantern.yml config over heuristics", %{tmp_dir: tmp_dir} do
      project_dir = Path.join(tmp_dir, "configured-app")
      File.mkdir_p!(project_dir)
      File.write!(Path.join(project_dir, "manage.py"), "#!/usr/bin/env python")

      File.write!(Path.join(project_dir, "lantern.yml"), """
      type: proxy
      run:
        cmd: "custom-start --port ${PORT}"
      """)

      project = Detector.detect(project_dir)
      assert project.run_cmd == "custom-start --port ${PORT}"
      assert project.detection.source == :config
      assert project.detection.confidence == :high
    end
  end

  describe "detect_package_manager/1" do
    test "detects pnpm", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "pnpm-lock.yaml"), "")
      assert Detector.detect_package_manager(tmp_dir) == :pnpm
    end

    test "detects yarn", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "yarn.lock"), "")
      assert Detector.detect_package_manager(tmp_dir) == :yarn
    end

    test "detects bun", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "bun.lockb"), "")
      assert Detector.detect_package_manager(tmp_dir) == :bun
    end

    test "detects npm", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "package-lock.json"), "{}")
      assert Detector.detect_package_manager(tmp_dir) == :npm
    end

    test "returns nil for no package manager", %{tmp_dir: tmp_dir} do
      assert Detector.detect_package_manager(tmp_dir) == nil
    end
  end
end
