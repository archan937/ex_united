defmodule ExUnited.Node do
  @moduledoc false

  @type t :: %__MODULE__{
          node: node,
          port: port,
          command: binary,
          env: keyword
        }

  defstruct [:node, :port, :command, env: []]
end
