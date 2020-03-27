defmodule Cristiano do
  @moduledoc false

  use GenServer

  @last_name "Ronaldo"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [counter: 0], name: name())
  end

  defp name, do: Cristiano.Server

  def init(state), do: {:ok, state}

  def say_hi do
    GenServer.call(name(), :say_hi)
  end

  def handle_call(:say_hi, _from, counter: counter) do
    counter = counter + 1

    first_name =
      __MODULE__
      |> Module.split()
      |> hd()

    greet =
      :void
      |> Application.get_env(:greet)
      |> String.replace("FULLNAME", "#{first_name} #{@last_name}")

    {:reply, "#{greet} (#{counter})", [counter: counter]}
  end
end
