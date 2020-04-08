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
  Spawns nodes for testing purposes. Supervised applications are supported.

  Nodes can be either specified as a list of atoms (such as `[:bruce, :clark]` for
  instance; the node names will be `:"bruce@127.0.0.1"` and `:"clark@127.0.0.1"`
  respectively) or as a keyword list (in case of configuring the spawned node).

  The following options are available to configure nodes:

    * `:code_paths` - a list of directories that will be included (please note
      that the file called `config.exs` is supported for `Mix.Config`)
    * `:supervise` - the child spec(s) used for supervisioning

  Aside from options for configuring individual nodes, as a second argument, you
  can pass a list of atoms for the following:

    * `:connect` - if `true` a "fully connected" node will be spawned (see
      the `erl -connect_all` flag for more information). Defaults to `false`
    * `:verbose` - if `true` the STDOUT of the spawned node will be printed.
      Defaults to `false`

  And last but not least, you can exclude certain (Mix) dependencies from your
  spawned nodes by adding `exclude: [:inch_ex]` to the options. This can
  significantly improve the speed of your tests.

  The following dependencies are excluded by default:

  * `:credo`
  * `:dialyxir`
  * `:ex_doc`
  * `:ex_united`
  * `:excoveralls`

  ## Examples

  The most simplest setup:

      setup do
        {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  Spawn "fully connected" nodes and print all their STDOUT in the console:

      setup do
        {:ok, spawned} = ExUnited.spawn([:bruce, :clark], [:connect, :verbose])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  Exclude certain dependencies:

      setup do
        {:ok, spawned} = ExUnited.spawn([:bruce, :clark], [:verbose, exclude: [:inch_ex]])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  A configured nodes setup:

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            bruce: [
              code_paths: [
                "test/nodes/bruce"
              ],
              supervise: [MyAwesomeGenServer]
            ],
            clark: [
              code_paths: [
                "test/nodes/clark"
              ],
              supervise: [MyOtherAwesomeGenServer]
            ]
          )

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  Also note that functions within childspecs should be quoted.

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            [
              roy: [
                code_paths: [
                  "test/nodes/keane"
                ],
                supervise: [
                  {
                    Roy,
                    talk:
                      quote do
                        fn
                          1 -> "Hi, I am Roy Keane"
                          2 -> "I am keen as mustard"
                          3 -> "I like to be peachy keen"
                        end
                      end
                  }
                ]
              ]
            ],
            [:verbose]
          )

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end
  """
  @spec spawn([node] | [{node, keyword}], [atom]) :: {:ok, [ExNode.t()]}
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
