defmodule TestHelper do
  def take(spawned, key) do
    spawned
    |> Enum.reduce([], fn
      {_name, %{node: _node, port: _port, env: _env} = node}, list ->
        list ++ [Map.get(node, key)]

      _, list ->
        list
    end)
  end
end

ExUnited.start()
