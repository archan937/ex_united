defmodule ExUnited.Spawn.State do
  @moduledoc """
  Represents the state of an `ExUnited.Spawn` instance. It stores:

    * `:color_index` - a cycling index used for allocating the output color of
      the next node to be spawned with 'verbose mode' enabled
    * `:nodes` - a map containing information about its spawned nodes
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
          color_index: integer,
          nodes: %{node: spawned_node}
        }

  defstruct color_index: 0, nodes: %{}

  @typedoc """
  A struct that keeps information about a spawned node:

    * `:node` - the node name of the spawned node
    * `:port` - the `Port` reference after having spawned the node
    * `:color` - the ANSI color code portion used when in 'verbose mode'
  """

  @type spawned_node :: %{
          node: node,
          port: port,
          color: binary | nil
        }
end
