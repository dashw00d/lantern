defmodule Lantern.System.Privilege do
  @moduledoc """
  Shared helpers for running privileged commands via sudo.
  Uses `sudo -n` (non-interactive) so commands fail immediately
  instead of hanging on a password prompt. Requires a sudoers.d
  file granting NOPASSWD for the specific commands Lantern uses.
  """

  require Logger

  @default_timeout 10_000

  @doc """
  Runs a command with `sudo -n`. Returns :ok or {:error, reason}.
  Includes a timeout (default 10s) so commands can never hang the caller.
  """
  def sudo(cmd, args \\ [], opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    task =
      Task.async(fn ->
        System.cmd("sudo", ["-n", cmd | args], stderr_to_stdout: true)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {_, 0}} ->
        :ok

      {:ok, {output, code}} ->
        msg = "#{cmd} #{Enum.join(args, " ")} failed (exit #{code}): #{String.trim(output)}"
        Logger.warning("[Privilege] #{msg}")
        {:error, msg}

      nil ->
        msg = "#{cmd} #{Enum.join(args, " ")} timed out after #{timeout}ms"
        Logger.warning("[Privilege] #{msg}")
        {:error, msg}
    end
  rescue
    e -> {:error, "Failed to run #{cmd}: #{Exception.message(e)}"}
  end

  @doc """
  Writes content to a privileged path via sudo cp from a temp file.
  """
  def sudo_write(path, content) do
    tmp = Path.join(System.tmp_dir!(), "lantern_priv_#{:rand.uniform(1_000_000)}")
    File.write!(tmp, content)

    result =
      case System.cmd("sudo", ["-n", "cp", tmp, path], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "Failed to write #{path}: #{String.trim(output)}"}
      end

    File.rm(tmp)
    result
  rescue
    e ->
      {:error, "Failed to write #{path}: #{Exception.message(e)}"}
  end
end
