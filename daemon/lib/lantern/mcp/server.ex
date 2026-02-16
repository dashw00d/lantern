defmodule Lantern.MCP.Server do
  @moduledoc """
  MCP (Model Context Protocol) server for Lantern.
  Exposes project management, health checking, documentation,
  and infrastructure tools to AI assistants.
  """

  use Hermes.Server,
    name: "lantern",
    version: "0.1.0",
    capabilities: [:tools, :resources, :prompts]

  # Tools
  component(Lantern.MCP.Tools.ListProjects)
  component(Lantern.MCP.Tools.GetProject)
  component(Lantern.MCP.Tools.GetProjectDocs)
  component(Lantern.MCP.Tools.GetProjectEndpoints)
  component(Lantern.MCP.Tools.GetProjectDiscovery)
  component(Lantern.MCP.Tools.CheckHealth)
  component(Lantern.MCP.Tools.StartProject)
  component(Lantern.MCP.Tools.StopProject)
  component(Lantern.MCP.Tools.RestartProject)
  component(Lantern.MCP.Tools.GetProjectLogs)
  component(Lantern.MCP.Tools.SearchProjects)
  component(Lantern.MCP.Tools.GetDependencies)
  component(Lantern.MCP.Tools.GetPorts)
  component(Lantern.MCP.Tools.RefreshDiscovery)

  # Resources
  component(Lantern.MCP.Resources.ProjectMetadata)
  component(Lantern.MCP.Resources.ProjectDocs)
  component(Lantern.MCP.Resources.ProjectDiscovery)

  # Prompts
  component(Lantern.MCP.Prompts.DiagnoseService)
  component(Lantern.MCP.Prompts.DependencyTrace)
end
