defmodule Roy do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    talk = Keyword.get(opts, :talk)
    GenServer.start_link(__MODULE__, %{counter: 0, talk: talk}, name: name())
  end

  defp name, do: Roy.Server

  def init(state), do: {:ok, state}

  def talk do
    GenServer.call(name(), :talk)
  end

  def handle_call(:talk, _from, %{counter: counter, talk: talk} = state) do
    counter = counter + 1
    greet = talk.(counter)

    {:reply, greet, %{state | counter: counter}}
  end
end
