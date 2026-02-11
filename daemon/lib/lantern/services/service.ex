defmodule Lantern.Services.Service do
  @moduledoc """
  Struct and behaviour for managed services (Mailpit, Redis, Postgres, etc.).
  """

  @type service_status :: :stopped | :starting | :running | :error

  @callback start() :: :ok | {:error, term()}
  @callback stop() :: :ok | {:error, term()}
  @callback status() :: service_status()
  @callback health_check() :: :ok | {:error, term()}

  defstruct [
    :name,
    :health_check_url,
    :module,
    status: :stopped,
    ports: %{},
    config: %{}
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          status: service_status(),
          ports: map(),
          config: map(),
          health_check_url: String.t() | nil,
          module: atom() | nil
        }

  def to_map(%__MODULE__{} = service) do
    %{
      name: service.name,
      status: service.status,
      ports: service.ports,
      config: service.config,
      health_check_url: service.health_check_url
    }
  end
end
