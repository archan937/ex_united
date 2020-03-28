defmodule TestHelper do
  def take(spawned, key) do
    spawned
    |> Enum.reduce([], fn
      {_name, %{node: _node, pid: _pid, env: _env} = node}, list ->
        list ++ [Map.get(node, key)]

      _, list ->
        list
    end)
  end

  def teardown(spawned) do
    ExUnited.stop(spawned)

    "/tmp/*-{config,mix}.exs"
    |> Path.wildcard()
    |> Enum.each(&File.rm/1)
  end
end

ExUnit.start()
