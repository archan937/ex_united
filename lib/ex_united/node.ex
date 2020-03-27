defmodule ExUnited.Node do
  @moduledoc false

  @type t :: %__MODULE__{
          node: node,
          pid: pid,
          command: binary,
          env: keyword
        }

  defstruct [:node, :pid, :command, env: []]
end
