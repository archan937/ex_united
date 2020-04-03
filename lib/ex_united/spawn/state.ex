defmodule ExUnited.Spawn.State do
  @moduledoc false

  @type t :: %__MODULE__{
          color_index: integer,
          nodes: map
        }

  defstruct color_index: 0,
            nodes: %{}
end
