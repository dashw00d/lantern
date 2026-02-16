defmodule LanternWeb.DeployController do
  use LanternWeb, :controller

  alias Lantern.Projects.{Manager, DeployRunner}

  def start(conn, %{"name" => name}), do: run_deploy(conn, name, :start)
  def stop(conn, %{"name" => name}), do: run_deploy(conn, name, :stop)
  def restart(conn, %{"name" => name}), do: run_deploy(conn, name, :restart)

  def logs(conn, %{"name" => name}) do
    with_project(conn, name, fn project ->
      case DeployRunner.execute(project, :logs) do
        {:ok, output} ->
          json(conn, %{data: %{project: name, output: output}})

        {:error, %{output: output, exit_code: code}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "deploy_failed", message: output, exit_code: code})

        {:error, message} when is_binary(message) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "deploy_failed", message: message})
      end
    end)
  end

  def status(conn, %{"name" => name}) do
    with_project(conn, name, fn project ->
      case DeployRunner.execute(project, :status) do
        {:ok, output} ->
          json(conn, %{data: %{project: name, output: output}})

        {:error, %{output: output, exit_code: code}} ->
          json(conn, %{data: %{project: name, output: output, exit_code: code}})

        {:error, message} when is_binary(message) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "deploy_failed", message: message})
      end
    end)
  end

  defp run_deploy(conn, name, command) do
    with_project(conn, name, fn project ->
      case DeployRunner.execute(project, command) do
        {:ok, output} ->
          json(conn, %{data: %{project: name, command: command, output: output}})

        {:error, %{output: output, exit_code: code}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "deploy_failed", message: output, exit_code: code})

        {:error, message} when is_binary(message) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "deploy_failed", message: message})
      end
    end)
  end

  defp with_project(conn, name, fun) do
    case Manager.get(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Project '#{name}' not found"})

      project ->
        fun.(project)
    end
  end
end
