defmodule Lantern.Projects.Scanner do
  @moduledoc """
  Scans workspace root directories to discover project paths.
  Walks one level deep, skipping hidden directories and common non-project folders.
  """

  @skip_dirs ~w(.git .hg .svn node_modules vendor _build deps .elixir_ls .cache .npm .yarn)

  @doc """
  Scans all configured workspace roots and returns a list of project paths.
  """
  def scan do
    workspace_roots = Application.get_env(:lantern, :workspace_roots, [Path.expand("~/sites")])

    workspace_roots
    |> Enum.flat_map(&scan_root/1)
    |> Enum.sort()
  end

  @doc """
  Scans a single workspace root directory one level deep.
  Returns list of absolute paths to potential project directories.
  """
  def scan_root(root) do
    root = Path.expand(root)

    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&skip?/1)
        |> Enum.map(&Path.join(root, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  end

  defp skip?(name) do
    String.starts_with?(name, ".") or name in @skip_dirs
  end
end
