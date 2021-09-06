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

  def generate_dummy_config() do
    File.mkdir_p!("/tmp/custom")

    File.write!("/tmp/custom/config.exs", """
    use Mix.Config

    config :void, single_config: :single_value
    config :void, multiple_config: [
        :multiple_value_one,
        :multiple_value_two
      ]
    config :void, nested_config: [
        nested_one: :nested_one,
        nested_two: [
          :nested_two_value_one,
          :nested_two_value_two
        ]
      ]
    config :another_app_config, key: :value

    """)
  end
end

ExUnited.start()
