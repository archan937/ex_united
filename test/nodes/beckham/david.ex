defmodule David do
  @moduledoc false

  use GenServer

  @phrases [
    "The only time you run out of chances is when you stop taking them.",
    "Always have something to look forward to.",
    "As a footballer, you always want to test yourself against the best.",
    "I don't do anything unless I can give it 100%."
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{counter: -1}, name: name())
  end

  defp name, do: David.Server

  def init(state), do: {:ok, state}

  def talk do
    GenServer.call(name(), :talk)
  end

  def handle_call(:talk, _from, %{counter: counter} = state) do
    counter =
      if counter == length(@phrases) - 1 do
        0
      else
        counter + 1
      end

    phrase = Enum.at(@phrases, counter)

    {:reply, phrase, %{state | counter: counter}}
  end
end
