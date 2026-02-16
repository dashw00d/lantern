defmodule Lantern.Projects.DeployRunner do
  @moduledoc """
  Stateless module for executing deploy shell commands defined in lantern.yaml.
  Commands come only from project configuration — never accepted via HTTP input.
  """

  alias Lantern.Projects.Project

  @valid_commands [:start, :stop, :restart, :logs, :status]

  @doc """
  Executes a deploy command for a project.
  Returns {:ok, output} or {:error, %{output: output, exit_code: code}}.
  """
  def execute(%Project{} = project, command) when command in @valid_commands do
    case get_command(project, command) do
      nil ->
        {:error, "No deploy.#{command} command configured for #{project.name}"}

      cmd_template ->
        cmd = Project.interpolate_cmd(cmd_template, project)
        run_command(cmd, project.path)
    end
  end

  def execute(_project, command) do
    {:error, "Invalid deploy command: #{inspect(command)}"}
  end

  defp get_command(%Project{deploy: deploy}, command) when is_map(deploy) do
    Map.get(deploy, command)
  end

  defp get_command(_, _), do: nil

  defp run_command(cmd, cwd) do
    opts = [
      stderr_to_stdout: true,
      cd: cwd
    ]

    try do
      case System.cmd("sh", ["-c", cmd], opts) do
        {output, 0} ->
          {:ok, String.trim(output)}

        {output, exit_code} ->
          {:error, %{output: String.trim(output), exit_code: exit_code}}
      end
    catch
      :exit, reason ->
        {:error, %{output: "Command timed out or failed: #{inspect(reason)}", exit_code: -1}}
    end
  end
end
