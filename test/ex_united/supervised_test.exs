defmodule ExUnited.SupervisedTest do
  use ExUnit.Case

  import TestHelper

  describe "supervised" do
    setup do
      {:ok, spawned} =
        ExUnited.spawn(
          cristiano: [
            code_paths: [
              "test/nodes/ronaldo"
            ],
            supervise: [Cristiano]
          ]
        )

      on_exit(fn ->
        ExUnited.teardown()
      end)

      spawned
    end

    test "spins up supervised nodes", spawned do
      captain = Node.self()
      [cristiano] = nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        other_nodes = [captain] ++ Enum.sort(nodes -- [node])
        assert ^other_nodes = :rpc.call(node, Node, :list, []) |> Enum.sort()
      end)

      assert [
               "iex --name cristiano@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)

      assert """
             use Mix.Config

             config :void,
               greet: "Hi, my name is FULLNAME"
             """ == File.read!("/tmp/cristiano-config.exs")

      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [{:inch_ex, "~> 2.0", [only: :inch, runtime: false]}],
                   elixirc_paths: ["test/nodes/ronaldo"],
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
                 Supervisor.start_link([Cristiano], opts)
               end
               defp load_config do
                 [void: [greet: "Hi, my name is FULLNAME"]]
                 |> Enum.each(fn {app, env} ->
                   Enum.each(env, fn {key, value} ->
                     Application.put_env(app, key, value)
                   end)
                 end)
               end
             end
             """ == File.read!("/tmp/cristiano-mix.exs")

      assert "Hi, my name is FULLNAME" =
               :rpc.call(cristiano, Application, :get_env, [:void, :greet])

      assert "Hi, my name is Cristiano Ronaldo (1)" =
               :rpc.call(cristiano, Cristiano, :say_hi, [])

      assert "Hi, my name is Cristiano Ronaldo (2)" =
               :rpc.call(cristiano, Cristiano, :say_hi, [])

      assert "Hi, my name is Cristiano Ronaldo (3)" =
               :rpc.call(cristiano, Cristiano, :say_hi, [])

      assert "Hi, my name is Cristiano Ronaldo (4)" =
               :rpc.call(cristiano, Cristiano, :say_hi, [])
    end
  end

  describe "supervised with a dynamic config" do
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

    test "spins up supervised nodes", spawned do
      captain = Node.self()
      [roy] = nodes = take(spawned, :node)

      assert :"captain@127.0.0.1" = captain
      assert ^nodes = Node.list() |> Enum.sort()

      Enum.each(nodes, fn node ->
        other_nodes = [captain] ++ Enum.sort(nodes -- [node])
        assert ^other_nodes = :rpc.call(node, Node, :list, []) |> Enum.sort()
      end)

      assert [
               "iex --name roy@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'"
             ] = take(spawned, :command)

      assert """
             defmodule Void.MixProject do
               use Mix.Project
               def project do
                 [
                   deps: [{:inch_ex, "~> 2.0", [only: :inch, runtime: false]}],
                   elixirc_paths: ["test/nodes/keane"],
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
                 Supervisor.start_link([{Roy, [talk: fn
               1 ->
                 "Hi, I am Roy Keane"
               2 ->
                 "I am keen as mustard"
               3 ->
                 "I like to be peachy keen"
             end]}], opts)
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
             """ == File.read!("/tmp/roy-mix.exs")

      assert "Hi, I am Roy Keane" = :rpc.call(roy, Roy, :talk, [])
      assert "I am keen as mustard" = :rpc.call(roy, Roy, :talk, [])
      assert "I like to be peachy keen" = :rpc.call(roy, Roy, :talk, [])
    end
  end
end
