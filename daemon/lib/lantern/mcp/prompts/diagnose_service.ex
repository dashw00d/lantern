defmodule Lantern.MCP.Prompts.DiagnoseService do
  @moduledoc "Template for diagnosing unhealthy services"
  use Hermes.Server.Component, type: :prompt

  alias Hermes.Server.Response

  schema do
    field :name, :string, required: true, description: "Project name to diagnose"
  end

  def get_messages(%{name: name}, frame) do
    response =
      Response.prompt()
      |> Response.user_message("""
      Please diagnose the service "#{name}" using the following steps:

      1. Check the health status using the check_health tool with name "#{name}"
      2. Get the project details using get_project with name "#{name}"
      3. Get recent logs using get_project_logs with name "#{name}"
      4. Check what depends on this service using get_dependencies with name "#{name}"

      Based on the results:
      - If the service is unhealthy, identify the likely cause from the logs
      - Suggest specific remediation steps
      - Note any downstream services that may be affected
      - If the service has deploy commands, suggest which one to run
      """)

    {:reply, response, frame}
  end
end
