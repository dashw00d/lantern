defmodule Lantern.Templates.Registry do
  @moduledoc """
  Registry for built-in and user-defined project templates.
  Loads from priv/templates/ and ~/.config/lantern/templates/.
  """

  use GenServer

  alias Lantern.Templates.Template

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def create(attrs) do
    GenServer.call(__MODULE__, {:create, attrs})
  end

  def update(name, attrs) do
    GenServer.call(__MODULE__, {:update, name, attrs})
  end

  def delete(name) do
    GenServer.call(__MODULE__, {:delete, name})
  end

  def fork(source_name, new_name) do
    GenServer.call(__MODULE__, {:fork, source_name, new_name})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    templates = load_builtin_templates() |> Map.merge(load_user_templates())
    {:ok, %{templates: templates}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.templates), state}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.templates, name), state}
  end

  @impl true
  def handle_call({:create, attrs}, _from, state) do
    template = struct(Template, Map.put(attrs, :builtin, false))
    new_templates = Map.put(state.templates, template.name, template)
    save_user_template(template)
    {:reply, {:ok, template}, %{state | templates: new_templates}}
  end

  @impl true
  def handle_call({:update, name, attrs}, _from, state) do
    case Map.get(state.templates, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      template ->
        updated = struct(template, attrs)
        new_templates = Map.put(state.templates, name, updated)

        unless updated.builtin do
          save_user_template(updated)
        end

        {:reply, {:ok, updated}, %{state | templates: new_templates}}
    end
  end

  @impl true
  def handle_call({:delete, name}, _from, state) do
    case Map.get(state.templates, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{builtin: true} ->
        {:reply, {:error, :cannot_delete_builtin}, state}

      _template ->
        new_templates = Map.delete(state.templates, name)
        delete_user_template(name)
        {:reply, :ok, %{state | templates: new_templates}}
    end
  end

  @impl true
  def handle_call({:fork, source_name, new_name}, _from, state) do
    case Map.get(state.templates, source_name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      source ->
        forked = %{source | name: new_name, builtin: false}
        new_templates = Map.put(state.templates, new_name, forked)
        save_user_template(forked)
        {:reply, {:ok, forked}, %{state | templates: new_templates}}
    end
  end

  # Private helpers

  defp load_builtin_templates do
    priv_dir = :code.priv_dir(:lantern)
    templates_dir = Path.join(priv_dir, "templates")

    case File.ls(templates_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.reduce(%{}, fn file, acc ->
          path = Path.join(templates_dir, file)

          case YamlElixir.read_from_file(path) do
            {:ok, data} when is_map(data) ->
              template = yaml_to_template(data, true)
              Map.put(acc, template.name, template)

            _ ->
              acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp load_user_templates do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    templates_dir = Path.join(state_dir, "templates")

    case File.ls(templates_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.reduce(%{}, fn file, acc ->
          path = Path.join(templates_dir, file)

          case YamlElixir.read_from_file(path) do
            {:ok, data} when is_map(data) ->
              template = yaml_to_template(data, false)
              Map.put(acc, template.name, template)

            _ ->
              acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp yaml_to_template(data, builtin) do
    %Template{
      name: data["name"],
      description: data["description"],
      type: safe_to_atom(data["type"]),
      run_cmd: get_in(data, ["run", "cmd"]),
      run_cwd: get_in(data, ["run", "cwd"]),
      run_env: get_in(data, ["run", "env"]) || %{},
      root: data["root"],
      features: atomize_map(data["features"] || %{}),
      builtin: builtin
    }
  end

  defp save_user_template(%Template{} = template) do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    templates_dir = Path.join(state_dir, "templates")
    File.mkdir_p!(templates_dir)

    data = %{
      "name" => template.name,
      "description" => template.description,
      "type" => to_string(template.type),
      "root" => template.root,
      "features" => stringify_map(template.features)
    }

    data =
      if template.run_cmd do
        Map.put(data, "run", %{
          "cmd" => template.run_cmd,
          "cwd" => template.run_cwd || ".",
          "env" => template.run_env
        })
      else
        data
      end

    path = Path.join(templates_dir, "#{template.name}.yml")
    # Write as YAML-compatible format using Jason since we don't have a YAML writer
    content =
      Enum.map_join(data, "\n", fn
        {"run", run} ->
          inner = Enum.map_join(run, "\n", fn {k, v} -> "  #{k}: \"#{v}\"" end)
          "run:\n#{inner}"

        {"features", features} ->
          inner = Enum.map_join(features, "\n", fn {k, v} -> "  #{k}: #{v}" end)
          "features:\n#{inner}"

        {_k, nil} ->
          ""

        {k, v} ->
          "#{k}: #{if is_binary(v), do: "\"#{v}\"", else: v}"
      end)

    File.write!(path, content <> "\n")
  end

  defp delete_user_template(name) do
    state_dir = Application.get_env(:lantern, :state_dir, Path.expand("~/.config/lantern"))
    path = Path.join([state_dir, "templates", "#{name}.yml"])
    File.rm(path)
  end

  defp safe_to_atom(nil), do: nil
  defp safe_to_atom(str) when is_binary(str), do: String.to_atom(str)
  defp safe_to_atom(atom) when is_atom(atom), do: atom

  defp atomize_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {safe_to_atom(k), v} end)
  end

  defp atomize_map(_), do: %{}

  defp stringify_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_map(_), do: %{}
end
