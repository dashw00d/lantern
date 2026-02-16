defmodule Mix.Tasks.PatchHermes do
  @moduledoc """
  Patches hermes_mcp's StreamableHTTP transport to use a 60s GenServer.call timeout
  instead of the default 5s. Without this, MCP tool calls that take longer than 5s
  will hang and then fail.

  Run manually:

      mix patch_hermes

  This task is also run automatically after `mix deps.get` via the alias in mix.exs.
  """

  use Mix.Task

  @shortdoc "Patches hermes_mcp GenServer.call timeouts to 60s"

  @target_file "deps/hermes_mcp/lib/hermes/server/transport/streamable_http.ex"

  # The two GenServer.call sites that need the timeout added.
  # Each pair is {unpatched_string, patched_string}.
  @patches [
    {
      "GenServer.call(transport, {:handle_message, session_id, message, context})",
      "GenServer.call(transport, {:handle_message, session_id, message, context}, 60_000)"
    },
    {
      "GenServer.call(\n      transport,\n      {:handle_message_for_sse, session_id, message, context}\n    )",
      "GenServer.call(\n      transport,\n      {:handle_message_for_sse, session_id, message, context},\n      60_000\n    )"
    }
  ]

  @impl Mix.Task
  def run(_args) do
    file = Path.join(Mix.Project.deps_path() |> Path.dirname(), @target_file)

    unless File.exists?(file) do
      Mix.shell().info("hermes_mcp dep not found at #{file}, skipping patch")
      exit(:normal)
    end

    content = File.read!(file)

    if String.contains?(content, "60_000") do
      Mix.shell().info("hermes_mcp already patched")
    else
      patched =
        Enum.reduce(@patches, content, fn {from, to}, acc ->
          String.replace(acc, from, to)
        end)

      if content == patched do
        Mix.shell().error("hermes_mcp patch patterns not found -- the dep may have changed")
      else
        File.write!(file, patched)
        Mix.shell().info("hermes_mcp patched: GenServer.call timeout set to 60_000ms")
      end
    end
  end
end
