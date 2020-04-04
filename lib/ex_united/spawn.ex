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

  @spec start_link() :: {:ok, pid}
  def start_link do
    GenServer.start_link(@spawn, %State{}, name: @spawn)
  end

  @spec init(State.t()) :: {:ok, State.t()}
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @spec terminate(atom, State.t()) :: :ok | :noop
  def terminate(_reason, state) do
    # coveralls-ignore-start
    {:reply, status, _state} =
      handle_call(:kill_all, {self(), make_ref()}, state)

    status
    # coveralls-ignore-stop
  end

  @spec legion() :: State.t()
  def legion do
    @spawn
    |> GenServer.whereis()
    |> :sys.get_state()
  end

  @spec spawn(atom, binary, keyword) :: port | :noop
  def spawn(name, command, opts \\ []) do
    GenServer.call(@spawn, {:spawn, name, command, opts})
  end

  @spec kill(atom | port) :: :ok | :noop
  def kill(name_or_port) do
    GenServer.call(@spawn, {:kill, name_or_port})
  end

  @spec kill_all() :: :ok | :noop
  def kill_all do
    GenServer.call(@spawn, :kill_all)
  end

  @spec handle_call(
          {:spawn, atom, binary, keyword},
          {pid, reference},
          State.t()
        ) ::
          {:reply, port | :noop, State.t()}
  def handle_call(
        {:spawn, name, command, opts},
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

          color_index =
            if color_index == length(@color) - 1, do: 0, else: color_index + 1

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

        case Port.info(port) do
          nil ->
            {:reply, :noop, state}

          info ->
            Port.close(port)
            os_pid = Keyword.get(info, :os_pid)
            System.cmd("kill", ["-9", "#{os_pid}"])
            {:reply, :ok, state}
        end

      nil ->
        {:reply, :noop, state}
    end
  end

  @spec handle_call(:kill_all, {pid, reference}, State.t()) ::
          {:reply, :ok | :noop, State.t()}
  def handle_call(:kill_all, from, %{nodes: nodes} = state) do
    nodes
    |> Enum.reduce({:reply, :ok, state}, fn {name, _port},
                                            {:reply, result, state} ->
      {reply, new_result, state} = handle_call({:kill, name}, from, state)
      {reply, hd(Enum.sort([result, new_result])), state}
    end)
  end

  @spec handle_info({port, {:data, binary}}, State.t()) :: {:noreply, State.t()}
  def handle_info({port, {:data, line}}, state) do
    case find(port, state) do
      {name, %{color: color}} ->
        if color do
          line = Regex.replace(~r/(^\s+|\s+$)/, line, "")
          IO.puts("\e[38;5;#{color}miex(#{name})>#{IO.ANSI.reset()} #{line}")
        end

      nil ->
        :noop
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

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
