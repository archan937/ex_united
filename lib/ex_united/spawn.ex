defmodule ExUnited.Spawn do
  @moduledoc false

  alias ExUnited.Spawn.State

  use GenServer

  @spawn __MODULE__

  @color ~w(
    38
    214
    199
    112
    177
    220
    36
  )

  @spec spawn(atom, binary, keyword) :: port | :noop
  def spawn(name, command, opts \\ []) do
    start_link()
    summon(name, command, opts)
  end

  @spec start_link() :: {:ok, pid} | :noop
  def start_link do
    if alive?() do
      :noop
    else
      System.at_exit(fn _ ->
        # coveralls-ignore-start
        kill_all()
        # coveralls-ignore-stop
      end)

      GenServer.start_link(@spawn, %State{}, name: @spawn)
    end
  end

  @spec alive?() :: boolean
  defp alive? do
    case GenServer.whereis(@spawn) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @spec init(State.t()) :: {:ok, State.t()}
  def init(state), do: {:ok, state}

  @spec summon(atom, binary, keyword) :: port | :noop
  defp summon(name, command, opts) do
    GenServer.call(@spawn, {:summon, name, command, opts})
  end

  @spec legion() :: State.t()
  def legion do
    if alive?() do
      @spawn
      |> GenServer.whereis()
      |> :sys.get_state()
    else
      :noop
    end
  end

  @spec kill(atom | port) :: :ok | :noop
  def kill(name_or_port) do
    if alive?() do
      GenServer.call(@spawn, {:kill, name_or_port})
    else
      :noop
    end
  end

  @spec kill_all() :: :ok
  def kill_all do
    if alive?() do
      GenServer.call(@spawn, :kill_all)
    else
      :noop
    end
  end

  @spec handle_call({:summon, atom, binary, keyword}, {pid, reference}, State.t()) ::
          {:reply, port | :noop, State.t()}
  def handle_call(
        {:summon, name, command, opts},
        _from,
        %{nodes: nodes, color_index: color_index} = state
      ) do
    if find(name, state) do
      {:reply, :noop, state}
    else
      env =
        opts
        |> Keyword.get(:env, [])
        |> to_erlang_env()

      {color, color_index} =
        if Keyword.get(opts, :verbose) do
          color = Enum.at(@color, color_index)
          color_index = if color_index == length(@color) - 1, do: 0, else: color_index + 1
          {color, color_index}
        else
          {nil, color_index}
        end

      port = Port.open({:spawn, command}, [:binary, env: env])
      nodes = Map.put(nodes, name, %{port: port, color: color})

      {:reply, port, %{state | nodes: nodes, color_index: color_index}}
    end
  end

  @spec handle_call({:kill, atom | port}, {pid, reference}, State.t()) ::
          {:reply, :ok | :noop, State.t()}
  def handle_call({:kill, name_or_port}, _from, %{nodes: nodes} = state) do
    case find(name_or_port, state) do
      {name, %{port: port}} ->
        state = %{state | nodes: Map.delete(nodes, name)}

        if Port.info(port) do
          Port.close(port)
          {:reply, :ok, state}
        else
          {:reply, :noop, state}
        end

      nil ->
        {:reply, :noop, state}
    end
  end

  @spec handle_call(:kill_all, {pid, reference}, State.t()) :: {:reply, :ok, State.t()}
  def handle_call(:kill_all, from, %{nodes: nodes} = state) do
    nodes
    |> Enum.reduce({:reply, :ok, state}, fn {name, _port}, {:reply, result, state} ->
      {reply, new_result, state} = handle_call({:kill, name}, from, state)
      {reply, hd(Enum.sort([result, new_result])), state}
    end)
  end

  @spec handle_info({port, {:data, binary}}, State.t()) :: {:noreply, State.t()}
  def handle_info({port, {:data, line}}, state) do
    {name, %{color: color}} = find(port, state)

    if color do
      line = Regex.replace(~r/(^\s+|\s+$)/, line, "")
      IO.puts("\e[38;5;#{color}miex(#{name})>#{IO.ANSI.reset()} #{line}")
    end

    {:noreply, state}
  end

  @spec to_erlang_env(keyword) :: [{charlist, charlist}]
  defp to_erlang_env(env) do
    Enum.map(env, fn {key, value} ->
      {to_charlist(key), to_charlist(value)}
    end)
  end

  @spec find(atom | port, State.t()) :: {atom, map} | nil
  defp find(name_or_port, %{nodes: nodes}) do
    Enum.find(nodes, fn {name, %{port: port}} ->
      Enum.member?([name, port], name_or_port)
    end)
  end
end
