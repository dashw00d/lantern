defmodule Lantern.Templates.Template do
  @moduledoc """
  Struct representing a project template (e.g. Laravel, Vite, Next.js).
  """

  defstruct [
    :name,
    :description,
    :type,
    :run_cmd,
    :run_cwd,
    :root,
    run_env: %{},
    features: %{},
    builtin: true
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          type: atom() | nil,
          run_cmd: String.t() | nil,
          run_cwd: String.t() | nil,
          run_env: map(),
          root: String.t() | nil,
          features: map(),
          builtin: boolean()
        }

  def to_map(%__MODULE__{} = template) do
    %{
      name: template.name,
      description: template.description,
      type: template.type,
      run_cmd: template.run_cmd,
      run_cwd: template.run_cwd,
      run_env: template.run_env,
      root: template.root,
      features: template.features,
      builtin: template.builtin
    }
  end
end
