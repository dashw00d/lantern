defmodule Lantern.Projects.DocServer do
  @moduledoc """
  Resolves and serves project documentation files.
  Validates paths to prevent directory traversal attacks.
  """

  alias Lantern.Projects.Project

  @doc """
  Lists all configured docs for a project with metadata (size, mtime, exists).
  """
  def list(%Project{} = project) do
    Enum.map(project.docs, fn doc ->
      full_path = resolve_path(project.path, doc.path)
      stat = safe_stat(full_path)

      Map.merge(doc, %{
        exists: stat != nil,
        size: if(stat, do: stat.size, else: nil),
        mtime: if(stat, do: NaiveDateTime.to_iso8601(stat.mtime), else: nil)
      })
    end)
  end

  @doc """
  Reads a doc file's content. Returns {:ok, content} or {:error, reason}.
  Validates the path stays within the project directory.
  """
  def read(%Project{} = project, relative_path) do
    with :ok <- validate_path(relative_path),
         full_path <- resolve_path(project.path, relative_path),
         :ok <- validate_within_project(full_path, project.path),
         {:ok, content} <- File.read(full_path) do
      {:ok, content}
    else
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_path(project_path, relative_path) do
    Path.join(project_path, relative_path)
    |> Path.expand()
  end

  defp validate_path(path) do
    if String.contains?(path, "\0") do
      {:error, :invalid_path}
    else
      :ok
    end
  end

  defp validate_within_project(full_path, project_path) do
    expanded_project = Path.expand(project_path)

    if String.starts_with?(full_path, expanded_project <> "/") or full_path == expanded_project do
      :ok
    else
      {:error, :path_traversal}
    end
  end

  defp safe_stat(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{type: :regular, size: size, mtime: mtime}} ->
        dt = DateTime.from_unix!(mtime) |> DateTime.to_naive()
        %{size: size, mtime: dt}

      _ ->
        nil
    end
  rescue
    _ -> nil
  end
end
