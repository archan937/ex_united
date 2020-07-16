defmodule ExUnited do
  @moduledoc """
  This module facilitates spawning nodes within tests.

  For using `ExUnited`, the two essential functions are:

    1. `ExUnited.spawn/2` - Spawns (`Mix.Config` configured, additional code loaded,
      supervising) nodes
    2. `ExUnited.teardown/0` - Kills the spawned nodes and it also cleans up their
      generated files

  ### The most simplest setup

  Nodes can be specified as a list of atoms, just like in the following example.
  Their node names will be `:"bruce@127.0.0.1"` and `:"clark@127.0.0.1"` respectively).

  Please do not forget to invoke `ExUnited.teardown/0` at the `on_exit` hook.

      setup do
        {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  ### "Partially versus Fully connected" and/or "Verbose" spawned nodes

  As a second argument, you can pass a list of atoms for the options:

    * `:connect` - if `true` a "fully connected" node will be spawned (see
      the `erl -connect_all` flag for more information). Defaults to `false`
    * `:verbose` - if `true` the STDOUT of the spawned node will be printed.
      Defaults to `false`

  See `ExUnited.spawn/2` for more information.

      setup do
        {:ok, spawned} = ExUnited.spawn([:roy], [:connect, :verbose])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  Which results in the following when running tests:

      PME-Legend ~/S/ex_united:master> mix test test/ex_united/supervised_test.exs:140
      Excluding tags: [:test]
      Including tags: [line: "140"]

      iex(roy@127.0.0.1)> Compiling 1 file (.ex)
      iex(roy@127.0.0.1)> Generated void app
      iex(roy@127.0.0.1)> Interactive Elixir (1.10.1) - press Ctrl+C to exit (type h() ENTER for help)
      iex(roy@127.0.0.1)1>
      .

      Finished in 0.9 seconds
      2 tests, 0 failures, 1 excluded

  ### Exclude certain dependencies within spawned nodes

  You can exclude certain (Mix) dependencies from your spawned nodes by for instance
  adding `exclude: [:inch_ex]` to the options. This can significantly improve
  the speed of your tests.

      setup do
        {:ok, spawned} = ExUnited.spawn([:bruce, :clark], [:verbose, exclude: [:inch_ex]])

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  The following dependencies are excluded by default:

  * `:credo`
  * `:dialyxir`
  * `:ex_doc`
  * `:ex_united`
  * `:excoveralls`

  ### Configuring the spawned nodes

  Aside from the list of atoms, you can also specify nodes as a keyword list in
  case you want to configure them. The following options are available:

  * `:code_paths` - a list of directories that will be included
  * `:exclude` - a list of dependencies that will be excluded
  * `:supervise` - the child spec(s) used for supervisioning

  ### Including additional code

  It would be a best practice to create a directory called `test/nodes` in which
  you put a directory containing code for a specific spawned node. Please note that
  the file called `config.exs` is supported for `Mix.Config`:

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            eric: [
              code_paths: [
                "test/nodes/cantona"
              ]
            ]
          )

        on_exit(fn ->
          ExUnited.teardown()
        end)

        spawned
      end

  See [test/ex_united/supervised_test.exs](https://github.com/archan937/ex_united/blob/v0.1.3/test/ex_united/supervised_test.exs#L7)
  with its corresponding [test/nodes/ronaldo](https://github.com/archan937/ex_united/tree/v0.1.3/test/nodes/ronaldo)
  as an example.

  ### Exclude certain dependencies for a specific spawned node

  Add the `:exclude` list as follows:

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            bruce: [
              code_paths: [
                "test/nodes/bruce"
              ],
              exclude: [
                :my_unused_dependency
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

  ### Add supervisioning

  Childspecs should be the same argument as if you are adding them to your classic
  `<app>/application.ex` file:

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

  Pay attention that functions within childspecs should be quoted.

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

  ### Easily assert and refute within the context of spawned nodes

  To seemlessly execute assertions and refutations within spawned nodes, you can
  setup your test module by either using `ExUnited.Case` instead of `ExUnit.Case`:

      defmodule MyNodesTest do
        use ExUnited.Case
      end

  Or by importing the `ExUnited.Case` module:

      defmodule MyNodesTest do
        use ExUnit.Case
        import ExUnited.Case
      end

  Writing assertions and refutations within the context of a certain spawned is
  pretty straight forward with the use of the `ExUnited.Case.as_node/2` function
  as if you are writing your class `assert` and/or `refute` statements:

      defmodule MyNodesTest do
        use ExUnited.Case

        setup do
          {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

          on_exit(fn ->
            ExUnited.teardown()
          end)

          spawned
        end

        test "assertions and refutations within node contexts", spawned do
          bruce = get_in(spawned, [:bruce, :node])

          as_node(bruce) do
            assert :"bruce@127.0.0.1" = Node.self()
            refute :"clark@127.0.0.1" == Node.self()
          end

          as_node(:clark) do
            assert :"clark@127.0.0.1" = Node.self()
            refute :"bruce@127.0.0.1" == Node.self()
          end
        end
      end

  See `ExUnited.Case.as_node/2` for more information.
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

  @included_dependencies []

  alias ExUnited.Node, as: ExNode
  alias ExUnited.Spawn, as: Simmons

  @doc """
  Starts both the `ExUnit` and `ExUnited.Spawn` gen servers. This should replace
  the default `ExUnit.start()` invocation in the test helper file.

      # test/test_helper.exs
      ExUnited.start()

  As of version `0.1.2`, you can also start `ExUnit` yourself explicitly and add
  `ExUnited.start(false)` instead:

      # test/test_helper.exs
      ExUnit.start()
      ExUnited.start(false)

  """
  @spec start(boolean) :: {:ok, pid}
  def start(start_ex_unit \\ true) do
    if start_ex_unit do
      ExUnit.start()
    end

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
    * `:exclude` - a list of dependencies that will be excluded
    * `:include` - a list of dependencies that will be included, in the format that is used in the mix file
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

  Exclude certain dependencies for all nodes:

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

  Exclude certain dependencies for a specific spawned node:

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            bruce: [
              code_paths: [
                "test/nodes/bruce"
              ],
              exclude: [
                :my_unused_dependency
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

  Include certain dependencies for a specific spawned node:

      setup do
        {:ok, spawned} =
          ExUnited.spawn(
            bruce: [
              code_paths: [
                "test/nodes/bruce"
              ],
              include: [
                {:my_lib, ">= 0.0.0"},
                {:another_lib, "~> 1.0"}
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

        generate_mix_exs(name, opts, spec)
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

  @spec generate_mix_exs(atom, [atom | keyword], keyword) :: :ok
  defp generate_mix_exs(name, opts, spec) do
    name
    |> mix_exs_path()
    |> File.write(mix_exs(opts, spec))

    :ok
  end

  @spec mix_exs_path(atom) :: binary
  defp mix_exs_path(name), do: "/tmp/#{name}-mix.exs"

  @spec mix_exs([atom | keyword], keyword) :: term
  def mix_exs(opts, spec) do
    config = Mix.Project.config()

    project =
      config
      |> Keyword.take([:version, :elixir, :build_path, :deps_path, :lockfile])
      |> Keyword.put(:app, :void)
      |> Keyword.put(:config_path, @emptyconfig)
      |> Keyword.put(:elixirc_paths, elixirc_paths(opts, spec))
      |> Keyword.put(:deps, deps(config, opts, spec))

    "../ex_united/mix.exs.eex"
    |> Path.expand(__ENV__.file)
    |> EEx.eval_file(
      project: project,
      all_env: read_config(opts, spec),
      supervised: supervised(spec)
    )
  end

  @spec elixirc_paths(keyword, keyword) :: list
  defp elixirc_paths(opts, spec) do
    app = Keyword.get(Mix.Project.config(), :app)

    exclude =
      @excluded_dependencies ++
        List.wrap(Keyword.get(opts, :exclude)) ++
        List.wrap(Keyword.get(spec, :exclude))

    code_paths =
      if Enum.member?(exclude, app) do
        []
      else
        ["lib"]
      end

    code_paths ++ Keyword.get(spec, :code_paths, [])
  end

  @spec deps(keyword, [atom | keyword], keyword) :: list
  defp deps(config, opts, spec) do
    exclude =
      @excluded_dependencies ++
        List.wrap(Keyword.get(opts, :exclude)) ++
        List.wrap(Keyword.get(spec, :exclude))

    include =
      @included_dependencies ++
        List.wrap(Keyword.get(opts, :include)) ++
        List.wrap(Keyword.get(spec, :include))

    config
    |> Keyword.get(:deps)
    |> Enum.reject(fn dep ->
      Enum.member?(exclude, elem(dep, 0))
    end)
    |> Enum.concat(include)
  end

  @spec read_config(keyword, keyword) :: keyword
  defp read_config(opts, spec) do
    config =
      opts
      |> elixirc_paths(spec)
      |> Enum.map(fn dir ->
        Path.wildcard("#{dir}/config.exs")
      end)
      |> List.flatten()
      |> case do
        [config] -> config
        [] -> @emptyconfig
      end

    if function_exported?(Config.Reader, :read!, 1) do
      Config.Reader
    else
      Mix.Config
    end
    |> apply(:read!, [config])
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
    mix_env = Application.get_env(:ex_united, :mix_env, Mix.env())

    {node, port, command, env} =
      Simmons.summon(
        name,
        env: [MIX_ENV: mix_env, MIX_EXS: mix_exs_path(name)],
        connect: Enum.member?(opts, :connect),
        verbose: Enum.member?(opts, :verbose)
      )

    %ExNode{node: node, port: port, command: command, env: env}
  end
end
