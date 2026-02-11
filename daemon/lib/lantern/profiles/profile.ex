defmodule Lantern.Profiles.Profile do
  @moduledoc """
  Struct representing a configuration profile (Light, Full Stack, Demo, etc.).
  """

  defstruct [
    :name,
    :description,
    services: [],
    auto_start_projects: [],
    env: %{},
    port_range_start: 41000,
    port_range_end: 42000
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          services: [String.t()],
          auto_start_projects: [String.t()],
          env: map(),
          port_range_start: non_neg_integer(),
          port_range_end: non_neg_integer()
        }

  def to_map(%__MODULE__{} = profile) do
    %{
      name: profile.name,
      description: profile.description,
      services: profile.services,
      auto_start_projects: profile.auto_start_projects,
      env: profile.env,
      port_range_start: profile.port_range_start,
      port_range_end: profile.port_range_end
    }
  end
end
