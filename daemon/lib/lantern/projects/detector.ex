defmodule Lantern.Projects.Detector do
  @moduledoc """
  Auto-detection engine that identifies project types from file system heuristics.
  Checks for lantern.yml first, then runs a heuristic chain.
  """

  alias Lantern.Config.LanternYml
  alias Lantern.Projects.Project

  @type detection_result :: %{
          type: Project.project_type(),
          confidence: Project.confidence(),
          source: :config | :auto,
          run_cmd: String.t() | nil,
          root: String.t() | nil,
          package_manager: atom() | nil,
          framework: String.t() | nil
        }

  @doc """
  Detects the project type at the given path.
  Returns a Project struct with detection metadata.
  """
  def detect(path) do
    name = Path.basename(path)

    case detect_from_config(path) do
      {:ok, project} ->
        project

      :none ->
        detection = detect_from_heuristics(path)
        pkg_manager = detect_package_manager(path)

        run_cmd =
          if detection.run_cmd && pkg_manager do
            maybe_replace_npx(detection.run_cmd, pkg_manager)
          else
            detection.run_cmd
          end

        Project.new(%{
          name: name,
          path: path,
          type: detection.type,
          run_cmd: run_cmd,
          root: detection.root,
          detection: %{
            confidence: detection.confidence,
            source: :auto,
            framework: detection.framework,
            package_manager: pkg_manager
          }
        })
    end
  end

  @doc """
  Detects the package manager used in a project by checking lockfiles.
  """
  def detect_package_manager(path) do
    cond do
      File.exists?(Path.join(path, "bun.lockb")) or File.exists?(Path.join(path, "bun.lock")) ->
        :bun

      File.exists?(Path.join(path, "pnpm-lock.yaml")) ->
        :pnpm

      File.exists?(Path.join(path, "yarn.lock")) ->
        :yarn

      File.exists?(Path.join(path, "package-lock.json")) ->
        :npm

      File.exists?(Path.join(path, "package.json")) ->
        :npm

      true ->
        nil
    end
  end

  # Private helpers

  defp detect_from_config(path) do
    config_path = find_config_file(path)

    if config_path do
      case LanternYml.parse(config_path) do
        {:ok, attrs} ->
          name = Path.basename(path)
          {:ok, LanternYml.to_project(attrs, name, path)}

        {:error, _} ->
          :none
      end
    else
      :none
    end
  end

  defp find_config_file(path) do
    yaml_path = Path.join(path, "lantern.yaml")
    yml_path = Path.join(path, "lantern.yml")

    cond do
      File.exists?(yaml_path) -> yaml_path
      File.exists?(yml_path) -> yml_path
      true -> nil
    end
  end

  defp detect_from_heuristics(path) do
    heuristics = [
      &detect_laravel/1,
      &detect_symfony/1,
      &detect_generic_php/1,
      &detect_nextjs/1,
      &detect_nuxt/1,
      &detect_remix/1,
      &detect_vite/1,
      &detect_fastapi/1,
      &detect_django/1,
      &detect_flask/1,
      &detect_static/1
    ]

    Enum.find_value(heuristics, default_detection(), fn heuristic ->
      case heuristic.(path) do
        nil -> false
        result -> result
      end
    end)
  end

  defp default_detection do
    %{
      type: :unknown,
      confidence: :low,
      run_cmd: nil,
      root: nil,
      framework: nil
    }
  end

  defp detect_laravel(path) do
    if File.exists?(Path.join(path, "artisan")) and
         File.exists?(Path.join(path, "public/index.php")) do
      %{type: :php, confidence: :high, run_cmd: nil, root: "public", framework: "laravel"}
    end
  end

  defp detect_symfony(path) do
    if File.exists?(Path.join(path, "bin/console")) and
         File.exists?(Path.join(path, "public/index.php")) do
      %{type: :php, confidence: :high, run_cmd: nil, root: "public", framework: "symfony"}
    end
  end

  defp detect_generic_php(path) do
    cond do
      File.exists?(Path.join(path, "public/index.php")) ->
        %{type: :php, confidence: :medium, run_cmd: nil, root: "public", framework: "php"}

      File.exists?(Path.join(path, "index.php")) ->
        %{type: :php, confidence: :medium, run_cmd: nil, root: ".", framework: "php"}

      true ->
        nil
    end
  end

  defp detect_nextjs(path) do
    if has_package_dep?(path, "next") do
      %{
        type: :proxy,
        confidence: :high,
        run_cmd: "npx next dev -p ${PORT}",
        root: nil,
        framework: "nextjs"
      }
    end
  end

  defp detect_nuxt(path) do
    if has_package_dep?(path, "nuxt") do
      %{
        type: :proxy,
        confidence: :high,
        run_cmd: "npx nuxi dev --port ${PORT}",
        root: nil,
        framework: "nuxt"
      }
    end
  end

  defp detect_remix(path) do
    if has_package_dep?(path, "@remix-run/dev") do
      %{
        type: :proxy,
        confidence: :high,
        run_cmd: "npx remix dev --port ${PORT}",
        root: nil,
        framework: "remix"
      }
    end
  end

  defp detect_vite(path) do
    if has_package_dep?(path, "vite") do
      %{
        type: :proxy,
        confidence: :medium,
        run_cmd: "npx vite --port ${PORT}",
        root: nil,
        framework: "vite"
      }
    end
  end

  defp detect_fastapi(path) do
    pyproject = Path.join(path, "pyproject.toml")

    if File.exists?(pyproject) do
      case File.read(pyproject) do
        {:ok, content} ->
          if String.contains?(content, "fastapi") do
            %{
              type: :proxy,
              confidence: :medium,
              run_cmd: "uvicorn app.main:app --port ${PORT}",
              root: nil,
              framework: "fastapi"
            }
          end

        _ ->
          nil
      end
    end
  end

  defp detect_django(path) do
    if File.exists?(Path.join(path, "manage.py")) do
      %{
        type: :proxy,
        confidence: :medium,
        run_cmd: "python manage.py runserver 127.0.0.1:${PORT}",
        root: nil,
        framework: "django"
      }
    end
  end

  defp detect_flask(path) do
    flask_files = [Path.join(path, "app.py"), Path.join(path, "wsgi.py")]

    Enum.find_value(flask_files, fn file ->
      if File.exists?(file) do
        case File.read(file) do
          {:ok, content} ->
            if String.contains?(content, "flask") or String.contains?(content, "Flask") do
              %{
                type: :proxy,
                confidence: :medium,
                run_cmd: "flask run --port ${PORT}",
                root: nil,
                framework: "flask"
              }
            end

          _ ->
            nil
        end
      end
    end)
  end

  defp detect_static(path) do
    if File.exists?(Path.join(path, "index.html")) do
      %{type: :static, confidence: :low, run_cmd: nil, root: ".", framework: "static"}
    end
  end

  defp has_package_dep?(path, dep_name) do
    pkg_path = Path.join(path, "package.json")

    if File.exists?(pkg_path) do
      case File.read(pkg_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, pkg} ->
              deps = Map.get(pkg, "dependencies", %{})
              dev_deps = Map.get(pkg, "devDependencies", %{})
              Map.has_key?(deps, dep_name) or Map.has_key?(dev_deps, dep_name)

            _ ->
              false
          end

        _ ->
          false
      end
    else
      false
    end
  end

  defp maybe_replace_npx(cmd, :pnpm), do: String.replace(cmd, "npx ", "pnpm exec ")
  defp maybe_replace_npx(cmd, :yarn), do: String.replace(cmd, "npx ", "yarn ")
  defp maybe_replace_npx(cmd, :bun), do: String.replace(cmd, "npx ", "bunx ")
  defp maybe_replace_npx(cmd, _), do: cmd
end
