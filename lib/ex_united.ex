defmodule ExUnited do
  @moduledoc """
  TODO
  """

  @emptyconfig Path.expand(
                 "../ex_united/config.exs",
                 __ENV__.file
               )

  @excluded_dependencies [
    :credo,
    :dialyxir,
    :ex_doc,
    :ex_united,
    :excoveralls
  ]

  alias ExUnited.Node, as: ExNode
  alias ExUnited.Spawn, as: Simmons

  @doc """
  Starts both the `ExUnit` and `ExUnited.Spawn` gen servers. This should replace
  the default `ExUnit.start()` invocation in the test helper file.

      # test/test_helper.exs
      ExUnited.start()

  """
  @spec start() :: {:ok, pid}
  def start do
    ExUnit.start()
    Simmons.start_link()
  end

  @doc """
  TODO
  """
  @spec spawn([node], [atom | keyword]) :: {:ok, [ExNode.t()]}
  def spawn(nodes, opts \\ []) do
    spawned =
      nodes
      |> Enum.map(fn node ->
        {name, spec} =
          case node do
            {_name, _spec} -> node
            name -> {name, []}
          end

        generate_files(name, opts, spec)
        {name, spawn_node(name, opts)}
      end)
      |> Enum.into(%{})

    {:ok, spawned}
  end

  @doc """
  Should be invoked at the end of a test which spawned nodes. This kills the
  nodes and it also cleans up their generated files located in
  `/tmp/[NODENAME]-{config,mix}.exs`.

  ## Example

      defmodule MyNodesTest do
        use ExUnit.Case

        setup do
          {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

          on_exit(fn ->
            ExUnited.teardown()
          end)

          spawned
        end

        test "does awesome stuff with spawned nodes", spawned do
          # a lot of awesome assertions and refutations
        end
      end
  """
  @spec teardown() :: :ok
  def teardown do
    Simmons.kill_all()

    "/tmp/*-{config,mix}.exs"
    |> Path.wildcard()
    |> Enum.each(&File.rm/1)

    :ok
  end

  @spec generate_files(atom, [atom | keyword], keyword) :: :ok
  defp generate_files(name, opts, spec) do
    name
    |> config_exs_path()
    |> File.write(config(spec))

    name
    |> mix_exs_path()
    |> File.write(mix(name, opts, spec))

    :ok
  end

  @spec config_exs_path(atom) :: binary
  defp config_exs_path(name), do: "/tmp/#{name}-config.exs"

  @spec mix_exs_path(atom) :: binary
  defp mix_exs_path(name), do: "/tmp/#{name}-mix.exs"

  @spec config(keyword) :: binary
  defp config(spec) do
    spec
    |> Keyword.get(:code_paths, [])
    |> List.wrap()
    |> Enum.map(fn dir ->
      Path.wildcard("#{dir}/config.exs")
    end)
    |> List.flatten()
    |> case do
      [config] -> File.read!(config)
      [] -> File.read!(@emptyconfig)
    end
  end

  @spec mix(atom, [atom | keyword], keyword) :: term
  defp mix(name, opts, spec) do
    config = Mix.Project.config()

    project =
      config
      |> Keyword.take([:version, :elixir])
      |> Keyword.put(:app, :void)
      |> Keyword.put(:config_path, @emptyconfig)
      |> Keyword.put(:elixirc_paths, elixirc_paths(spec))
      |> Keyword.put(:deps, deps(config, opts))

    "../ex_united/mix.exs.eex"
    |> Path.expand(__ENV__.file)
    |> EEx.eval_file(
      project: project,
      all_env: read_config(name),
      supervised: supervised(spec)
    )
  end

  @spec elixirc_paths(keyword) :: list
  defp elixirc_paths(spec) do
    Keyword.get(spec, :code_paths, [])
  end

  @spec deps(keyword, [atom | keyword]) :: list
  defp deps(config, opts) do
    exclude =
      opts
      |> Keyword.get(:exclude)
      |> List.wrap()
      |> Kernel.++(@excluded_dependencies)

    config
    |> Keyword.get(:deps)
    |> Kernel.++([{Keyword.get(config, :app), path: File.cwd!()}])
    |> Enum.reject(fn dep ->
      Enum.member?(exclude, elem(dep, 0))
    end)
  end

  defp read_config(name) do
    if function_exported?(Config.Reader, :read!, 1) do
      Config.Reader
    else
      Mix.Config
    end
    |> apply(:read!, [config_exs_path(name)])
  end

  @spec supervised(keyword) :: binary
  defp supervised(spec) do
    case Keyword.get(spec, :supervise) do
      nil ->
        "[]"

      children ->
        Macro.to_string(children)
    end
  end

  @spec spawn_node(atom, [atom]) :: ExNode.t()
  defp spawn_node(name, opts) do
    {node, port, command, env} =
      Simmons.summon(
        name,
        env: [MIX_EXS: mix_exs_path(name)],
        connect: Enum.member?(opts, :connect),
        verbose: Enum.member?(opts, :verbose)
      )

    %ExNode{node: node, port: port, command: command, env: env}
  end
end
