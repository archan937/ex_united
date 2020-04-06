defmodule ExUnited.Node do
  @moduledoc """
  A struct containing information about a spawned node for use in ExUnit tests:

    * `:node` - the node name of the spawned node
    * `:port` - the corresponding `Port` reference of the spawned node
    * `:command` - the command used for spawning the node
    * `:env` - the list containing environment variables used spawning the node

  See `ExUnited.Spawn.summon/2` for more information.
  """

  @behaviour Access

  # coveralls-ignore-start

  @doc false
  defdelegate fetch(term, key), to: Map

  @doc false
  defdelegate get(term, key, default), to: Map

  @doc false
  defdelegate get_and_update(term, key, fun), to: Map

  @doc false
  defdelegate pop(map, key), to: Map

  # coveralls-ignore-stop

  @type t :: %__MODULE__{
          node: node,
          port: port,
          command: binary,
          env: [{charlist, charlist}]
        }

  defstruct [:node, :port, :command, env: []]
end
