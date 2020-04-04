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

  @spec spawn(node, keyword) ::
          {port, binary, [{charlist, charlist}]} | :noop
  def spawn(node, opts \\ []) do
    GenServer.call(@spawn, {:spawn, node, opts})
  end

  @spec kill(node | port) :: :ok | :noop
  def kill(node_or_port) do
    GenServer.call(@spawn, {:kill, node_or_port})
  end

  @spec kill_all() :: :ok | :noop
  def kill_all do
    GenServer.call(@spawn, :kill_all)
  end

  @spec handle_call(
          {:spawn, node, keyword},
          {pid, reference},
          State.t()
        ) ::
          {:reply, {port, binary, [{charlist, charlist}]} | :noop, State.t()}
  def handle_call(
        {:spawn, node, opts},
        _from,
        %{nodes: nodes, color_index: index} = state
      ) do
    if find(node, state) do
      {:reply, :noop, state}
    else
      connect =
        unless Keyword.get(opts, :connect) do
          " --erl '-connect_all false'"
        end

      command =
        ~s[iex --name #{node}#{connect} -S mix run -e 'Node.connect(#{
          inspect(Node.self())
        })']

      env =
        opts
        |> Keyword.get(:env, [])
        |> to_erlang_env()

      {color, index} =
        if Keyword.get(opts, :verbose) do
          color = Enum.at(@color, index)

          index = if index == length(@color) - 1, do: 0, else: index + 1

          {color, index}
        else
          {nil, index}
        end

      port = Port.open({:spawn, command}, [:binary, env: env])
      nodes = Map.put(nodes, node, %{port: port, color: color})

      await_node(node, Keyword.get(opts, :connect))

      {:reply, {port, command, env},
       %{state | nodes: nodes, color_index: index}}
    end
  end

  @spec handle_call({:kill, node | port}, {pid, reference}, State.t()) ::
          {:reply, :ok | :noop, State.t()}
  def handle_call({:kill, node_or_port}, _from, %{nodes: nodes} = state) do
    case find(node_or_port, state) do
      {node, %{port: port}} ->
        state = %{state | nodes: Map.delete(nodes, node)}

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
    |> Enum.reduce({:reply, :ok, state}, fn {node, _port},
                                            {:reply, result, state} ->
      {reply, new_result, state} = handle_call({:kill, node}, from, state)
      {reply, hd(Enum.sort([result, new_result])), state}
    end)
  end

  @spec handle_info({port, {:data, binary}}, State.t()) :: {:noreply, State.t()}
  def handle_info({port, {:data, line}}, state) do
    case find(port, state) do
      {node, %{color: color}} ->
        if color do
          line = Regex.replace(~r/(^\s+|\s+$)/, line, "")
          IO.puts("\e[38;5;#{color}miex(#{node})>#{IO.ANSI.reset()} #{line}")
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

  @spec await_node(node, boolean) :: :ok
  defp await_node(node, connect) do
    if Enum.member?(Node.list(), node) do
      if connect do
        [last | others] = Node.list() |> Enum.reverse()

        Enum.each(others, fn node ->
          :rpc.call(last, Node, :connect, [node])
        end)
      end
    else
      Process.sleep(100)
      await_node(node, connect)
    end

    :ok
  end

  @spec find(node | port, State.t()) :: {node, map} | nil
  defp find(node_or_port, %{nodes: nodes}) do
    Enum.find(nodes, fn {node, %{port: port}} ->
      Enum.member?([node, port], node_or_port)
    end)
  end
end
