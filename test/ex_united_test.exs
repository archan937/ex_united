defmodule ExUnitedTest do
  use ExUnit.Case

  import TestHelper

  describe "zero-config" do
    setup do
      {:ok, spawned} = ExUnited.spawn([:ryan, :george, :bobby])

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "generates config and mix files", spawned do
      assert [
               [MIX_EXS: "/tmp/bobby-mix.exs"],
               [MIX_EXS: "/tmp/george-mix.exs"],
               [MIX_EXS: "/tmp/ryan-mix.exs"]
             ] = take(spawned, :env)

      assert """
             use Mix.Config

             # Nothing to see here (sorry)
             """ == File.read!("/tmp/ryan-config.exs")

      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [
                     {:credo, "~> 1.3", [only: [:dev, :test], runtime: false]},
                     {:dialyxir, "~> 1.0", [only: [:dev], runtime: false]},
                     {:excoveralls, "~> 0.12.3", [only: [:dev, :test]]}
                   ],
                   elixirc_paths: [],
                   config_path: "#{File.cwd!()}/lib/ex_united/config.exs",
                   app: :void,
                   version: "0.1.0",
                   elixir: "#{Keyword.get(Mix.Project.config(), :elixir)}"
                 ]
               end
               def application do
                 [mod: {Void.Application, []}]
               end
             end

             defmodule Void.Application do
               use Application
               def start(_type, _args) do
                 load_config()
                 opts = [strategy: :one_for_one, name: Void.Supervisor]
                 Supervisor.start_link([], opts)
               end
               defp load_config do
                 []
                 |> Enum.each(fn {app, env} ->
                   Enum.each(env, fn {key, value} ->
                     Application.put_env(app, key, value)
                   end)
                 end)
               end
             end
             """ == File.read!("/tmp/bobby-mix.exs")
    end

    test "spins up \"partially\" connected nodes", spawned do
      captain = Node.self()
      nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        assert [^captain] = :rpc.call(node, Node, :list, [])
      end)

      assert [
               "iex --name bobby@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'",
               "iex --name george@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'",
               "iex --name ryan@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)
    end
  end

  describe "dependencies" do
    setup do
      {:ok, spawned} = ExUnited.spawn([:ryan], exclude: [:credo, :dialyxir])

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "excludes specified dependencies" do
      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [{:excoveralls, \"~> 0.12.3\", [only: [:dev, :test]]}],
                   elixirc_paths: [],
                   config_path: "#{File.cwd!()}/lib/ex_united/config.exs",
                   app: :void,
                   version: "0.1.0",
                   elixir: "#{Keyword.get(Mix.Project.config(), :elixir)}"
                 ]
               end
               def application do
                 [mod: {Void.Application, []}]
               end
             end

             defmodule Void.Application do
               use Application
               def start(_type, _args) do
                 load_config()
                 opts = [strategy: :one_for_one, name: Void.Supervisor]
                 Supervisor.start_link([], opts)
               end
               defp load_config do
                 []
                 |> Enum.each(fn {app, env} ->
                   Enum.each(env, fn {key, value} ->
                     Application.put_env(app, key, value)
                   end)
                 end)
               end
             end
             """ == File.read!("/tmp/ryan-mix.exs")
    end
  end

  describe "fully connected" do
    setup do
      {:ok, spawned} = ExUnited.spawn([:denis, :paul, :duncan], [:connect])

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "spins up fully connected nodes", spawned do
      captain = Node.self()
      nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        other_nodes = [captain] ++ Enum.sort(nodes -- [node])
        assert ^other_nodes = :rpc.call(node, Node, :list, []) |> Enum.sort()
      end)

      assert [
               "iex --name denis@127.0.0.1 -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'",
               "iex --name duncan@127.0.0.1 -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'",
               "iex --name paul@127.0.0.1 -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)
    end
  end

  describe "configured" do
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

    test "spins up configured nodes", spawned do
      captain = Node.self()
      [eric] = nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        other_nodes = [captain] ++ Enum.sort(nodes -- [node])
        assert ^other_nodes = :rpc.call(node, Node, :list, []) |> Enum.sort()
      end)

      assert [
               "iex --name eric@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)

      assert """
             use Mix.Config

             config :void,
               question: "T'as pigé?"
             """ == File.read!("/tmp/eric-config.exs")

      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [
                     {:credo, "~> 1.3", [only: [:dev, :test], runtime: false]},
                     {:dialyxir, "~> 1.0", [only: [:dev], runtime: false]},
                     {:excoveralls, "~> 0.12.3", [only: [:dev, :test]]}
                   ],
                   elixirc_paths: ["test/nodes/cantona"],
                   config_path: "#{File.cwd!()}/lib/ex_united/config.exs",
                   app: :void,
                   version: "0.1.0",
                   elixir: "#{Keyword.get(Mix.Project.config(), :elixir)}"
                 ]
               end
               def application do
                 [mod: {Void.Application, []}]
               end
             end

             defmodule Void.Application do
               use Application
               def start(_type, _args) do
                 load_config()
                 opts = [strategy: :one_for_one, name: Void.Supervisor]
                 Supervisor.start_link([], opts)
               end
               defp load_config do
                 [void: [question: "T'as pigé?"]]
                 |> Enum.each(fn {app, env} ->
                   Enum.each(env, fn {key, value} ->
                     Application.put_env(app, key, value)
                   end)
                 end)
               end
             end
             """ == File.read!("/tmp/eric-mix.exs")

      assert "T'as pigé?" =
               :rpc.call(eric, Application, :get_env, [:void, :question])
    end
  end

  describe "code paths" do
    setup do
      {:ok, spawned} =
        ExUnited.spawn(
          wayne: [
            code_paths: [
              "test/nodes/rooney"
            ]
          ]
        )

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "spins up nodes with loaded code paths", spawned do
      captain = Node.self()
      [wayne] = nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        other_nodes = [captain] ++ Enum.sort(nodes -- [node])
        assert ^other_nodes = :rpc.call(node, Node, :list, []) |> Enum.sort()
      end)

      assert [
               "iex --name wayne@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)

      assert """
             use Mix.Config

             # Nothing to see here (sorry)
             """ == File.read!("/tmp/wayne-config.exs")

      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [
                     {:credo, "~> 1.3", [only: [:dev, :test], runtime: false]},
                     {:dialyxir, "~> 1.0", [only: [:dev], runtime: false]},
                     {:excoveralls, "~> 0.12.3", [only: [:dev, :test]]}
                   ],
                   elixirc_paths: ["test/nodes/rooney"],
                   config_path: "#{File.cwd!()}/lib/ex_united/config.exs",
                   app: :void,
                   version: "0.1.0",
                   elixir: "#{Keyword.get(Mix.Project.config(), :elixir)}"
                 ]
               end
               def application do
                 [mod: {Void.Application, []}]
               end
             end

             defmodule Void.Application do
               use Application
               def start(_type, _args) do
                 load_config()
                 opts = [strategy: :one_for_one, name: Void.Supervisor]
                 Supervisor.start_link([], opts)
               end
               defp load_config do
                 []
                 |> Enum.each(fn {app, env} ->
                   Enum.each(env, fn {key, value} ->
                     Application.put_env(app, key, value)
                   end)
                 end)
               end
             end
             """ == File.read!("/tmp/wayne-mix.exs")

      assert "Hey, my name is Wayne Rooney. Not Bruce Wayne :D" =
               :rpc.call(wayne, Wayne, :hello?, [])
    end
  end
end
