defmodule Lantern.MCP.Prompts.DependencyTrace do
  @moduledoc "Template for tracing what depends on a given project"
  use Hermes.Server.Component, type: :prompt

  alias Hermes.Server.Response

  schema do
    field :name, :string, required: true, description: "Project name to trace dependencies for"
  end

  def get_messages(%{name: name}, frame) do
    response =
      Response.prompt()
      |> Response.user_message("""
      Trace the dependency chain for project "#{name}":

      1. Get the dependency graph using get_dependencies with name "#{name}"
      2. For each project that depends on "#{name}", also get their details using get_project
      3. Check the health of all related projects using check_health

      Provide a summary that includes:
      - Direct dependencies of "#{name}" (what it needs)
      - Projects that depend on "#{name}" (what would break if it goes down)
      - Current health status of each related project
      - Risk assessment: what's the blast radius if "#{name}" fails?
      """)

    {:reply, response, frame}
  end
end
