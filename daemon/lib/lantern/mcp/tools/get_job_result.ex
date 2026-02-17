defmodule Lantern.MCP.Tools.GetJobResult do
  @moduledoc "Poll for the result of an async job submitted via call_tool_api"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias Lantern.MCP.Jobs

  schema do
    field(:job_id, :string, required: true, description: "Job ID returned by call_tool_api")
  end

  def execute(%{job_id: job_id}, frame) do
    case Jobs.get(job_id) do
      {:ok, :running, info} ->
        {:reply,
         Response.tool()
         |> Response.json(%{
           status: "running",
           elapsed_ms: info.elapsed_ms,
           message: "Still processing. Poll again shortly."
         }), frame}

      {:ok, :completed, {:ok, body}} ->
        {:reply, Response.tool() |> Response.text(body), frame}

      {:ok, :completed, result} ->
        {:reply, Response.tool() |> Response.json(%{status: "completed", result: result}), frame}

      {:ok, :failed, {:error, reason}} ->
        {:error, Error.execution("Job failed: #{reason}"), frame}

      {:ok, :failed, reason} ->
        {:error, Error.execution("Job failed: #{inspect(reason)}"), frame}

      {:error, :not_found} ->
        {:error, Error.execution("Job '#{job_id}' not found (may have expired)"), frame}
    end
  end
end
