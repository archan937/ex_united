defmodule ExUnited.Spawn do
  @moduledoc """
  This module is used by `ExUnited` to spawn nodes for testing purposes.

  `ExUnited.Spawn` uses the Elixir `Port` module for spawning and as it
  implements the GenServer behaviour it is able to store state containing
  information about the spawn nodes.

  You will probably _**not**_ talk to this module directly. Though you can of course
  try out things in the console.

  ## Example

      iex(1)> ExUnited.Spawn.start_link()
      {:ok, #PID<0.198.0>}

      iex(2)> Node.start(:"captain@127.0.0.1")
      {:ok, #PID<0.200.0>}

      iex(captain@127.0.0.1)3> ExUnited.Spawn.summon(:"bruce@127.0.0.1", env: [PORT: 5000], verbose: true)
      iex(bruce@127.0.0.1)> Interactive Elixir (1.10.1) - press Ctrl+C to exit (type h() ENTER for help)
      iex(bruce@127.0.0.1)1>
      {#Port<0.8>,
       "iex --name bruce@127.0.0.1 --erl '-connect_all false' -S mix run -e 'Node.connect(:\"captain@127.0.0.1\")'",
       [{'PORT', '5000'}]}

      iex(captain@127.0.0.1)4> Node.list()
      [:"bruce@127.0.0.1"]

      iex(captain@127.0.0.1)5> ExUnited.Spawn.legion()
      %ExUnited.Spawn.State{
        color_index: 1,
        nodes: %{bruce: %{color: "38", node: :"bruce@127.0.0.1", port: #Port<0.8>}}
      }

      iex(captain@127.0.0.1)6> ExUnited.Spawn.kill_all()
      :ok
  """

  alias ExUnited.Spawn.State

  use GenServer

  @nodename :captain
  @nodehost '127.0.0.1'

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

  @doc """
  Starts the spawn server. The gen server spawnes nodes and stores their
  references in its state.
  """
  @spec start_link() :: {:ok, pid}
  def start_link do
    GenServer.start_link(@spawn, %State{}, name: @spawn)
  end

  @doc false
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

  @doc """
  Returns a `%ExUnited.Spawn.State{}` containing all its spawned nodes.

      iex(captain@127.0.0.1)8> ExUnited.Spawn.legion()
      %ExUnited.Spawn.State{
        color_index: 4,
        nodes: %{
          bruce: %{color: nil, node: :"bruce@127.0.0.1", port: #Port<0.8>},
          clark: %{color: "214", node: :"clark@127.0.0.1", port: #Port<0.12>},
          peter: %{color: "38", node: :"peter@127.0.0.1", port: #Port<0.10>},
          steven: %{color: "112", node: :"steven@127.0.0.1", port: #Port<0.16>},
          tony: %{color: "199", node: :"tony@127.0.0.1", port: #Port<0.14>}
        }
      }

  See `ExUnited.Spawn.State` for more information.
  """
  @spec legion() :: State.t()
  def legion do
    @spawn
    |> GenServer.whereis()
    |> :sys.get_state()
  end

  @doc """
  Spawns a new node using the specified node name.

  These options are supported:

    * `:env` - should be a keyword list containing the environment variables
      which will be used for the spawned node
    * `:connect` - if `true` a "fully connected" node will be spawned (see
      the `erl -connect_all` flag for more information). Defaults to `false`
    * `:verbose` - if `true` the STDOUT of the spawned node will be printed.
      Defaults to `false`

  It returns a tuple conforming the following structure:

      {node, port, command, env}

  where:

    * `node` - the full nodename of the spawned node (the `Node.self()` value)
    * `port` - the corresponding `Port` reference of the spawned node
    * `command` - the command used for spawning the node
    * `env` - the list containing environment variables used spawning the node

  ## Example

      {node, port, command, env} = ExUnited.Spawn.summon(:"peter@127.0.0.1", [
        MIX_EXS: "/tmp/peter-mix.exs",
        verbose: true
      ])

  If the name already seems to be registered then a `:noop` will be returned
  without spawning the node.
  """
  @spec summon(atom, keyword) ::
          {node, port, binary, [{charlist, charlist}]} | :noop
  def summon(name, opts \\ []) do
    GenServer.call(@spawn, {:summon, name, opts})
  end

  @doc """
  Kills and unregisters a spawned node identified by its node name or port.
  """
  @spec kill(atom | port) :: :ok | :noop
  def kill(name_or_port) do
    GenServer.call(@spawn, {:kill, name_or_port})
  end

  @doc """
  Kills and unregisters all spawned nodes. If either of the nodes failed to be
  killed the return value will be `:noop` and elsewise the return value is `:ok`.
  """
  @spec kill_all() :: :ok | :noop
  def kill_all do
    Node.stop()
    GenServer.call(@spawn, :kill_all)
  end

  @spec handle_call(
          {:summon, atom, keyword},
          {pid, reference},
          State.t()
        ) ::
          {:reply, {node, port, binary, [{charlist, charlist}]} | :noop,
           State.t()}
  def handle_call(
        {:summon, name, opts},
        _from,
        %{nodes: nodes, color_index: index} = state
      ) do
    if find(name, state) do
      {:reply, :noop, state}
    else
      Node.start(:"#{@nodename}@#{@nodehost}")
      node = :"#{name}@#{@nodehost}"

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
      nodes = Map.put(nodes, name, %{node: node, port: port, color: color})

      await_node(node, Keyword.get(opts, :connect))

      {:reply, {node, port, command, env},
       %{state | nodes: nodes, color_index: index}}
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
      {_name, %{node: node, color: color}} ->
        if color do
          {prompt, line} = derive_prompt(node, line)
          IO.puts("\e[38;5;#{color}m#{prompt}#{IO.ANSI.reset()} #{line}")
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

  @spec find(atom | port, State.t()) :: {atom, State.spawned_node()} | nil
  defp find(name_or_port, %{nodes: nodes}) do
    Enum.find(nodes, fn {name, %{port: port}} ->
      Enum.member?([name, port], name_or_port)
    end)
  end

  @spec derive_prompt(node, binary) :: {binary, binary}
  defp derive_prompt(node, line) do
    regex = ~r/^\s*(?<prompt>iex.*?\)\d+>)?(?<line>.*?)\s*$/

    case Regex.named_captures(regex, line) do
      # coveralls-ignore-start
      nil -> {"iex(#{node})>", line}
      # coveralls-ignore-stop
      %{"prompt" => "", "line" => line} -> {"iex(#{node})>", line}
      %{"prompt" => prompt, "line" => line} -> {prompt, line}
    end
  end
end
