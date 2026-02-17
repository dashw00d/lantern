defmodule Lantern.Projects.Scanner do
  @moduledoc """
  Scans workspace root directories to discover project paths.
  Walks one level deep, skipping hidden directories and common non-project folders,
  and only includes folders that contain `lantern.yaml` or `lantern.yml`.
  """

  @skip_dirs ~w(.git .hg .svn node_modules vendor _build deps .elixir_ls .cache .npm .yarn)

  @doc """
  Scans all configured workspace roots and returns a list of project paths.
  """
  def scan do
    workspace_roots = Lantern.Config.Settings.get(:workspace_roots)

    workspace_roots =
      if workspace_roots == [] or workspace_roots == nil,
        do: [Path.expand("~/sites"), Path.expand("~/tools")],
        else: workspace_roots

    workspace_roots
    |> Enum.flat_map(&scan_root/1)
    |> Enum.sort()
  end

  @doc """
  Scans a single workspace root directory one level deep.
  Returns list of absolute paths to manifest-backed project directories.
  """
  def scan_root(root) do
    root = Path.expand(root)

    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&skip?/1)
        |> Enum.map(&Path.join(root, &1))
        |> Enum.filter(&File.dir?/1)
        |> Enum.filter(&manifest_present?/1)

      {:error, _} ->
        []
    end
  end

  defp skip?(name) do
    String.starts_with?(name, ".") or name in @skip_dirs
  end

  defp manifest_present?(path) do
    File.exists?(Path.join(path, "lantern.yaml")) or File.exists?(Path.join(path, "lantern.yml"))
  end
end
