defmodule ExUnited do
  @moduledoc false

  @nodename :captain
  @nodehost '127.0.0.1'

  @emptyconfig Path.expand(
                 "../ex_united/config.exs",
                 __ENV__.file
               )

  @excluded_dependencies [:ex_united, :porcelain]

  alias ExUnited.Node, as: UNoded

  @spec start([node], [atom | keyword]) :: {:ok, [UNoded.t()]}
  def start(nodes, opts \\ []) do
    Node.start(:"#{@nodename}@#{@nodehost}")

    spawned =
      nodes
      |> Enum.map(fn node ->
        {name, spec} =
          case node do
            {_name, _spec} -> node
            name -> {name, []}
          end

        generate_files(name, opts, spec)
        {name, spawn_node(name, opts)}
      end)
      |> Enum.into(%{})

    {:ok, spawned}
  end

  @spec stop() :: :ok
  def stop do
    Porcelain.shell(
      "ps aux | grep iex | grep 'Node.connect(:\"captain@127.0.0.1\")' | grep -v grep | awk '{print $2}' | xargs kill -9"
    )

    :ok
  end

  @spec generate_files(atom, [atom | keyword], keyword) :: :ok
  defp generate_files(name, opts, spec) do
    name
    |> config_exs_path()
    |> File.write(config(spec))

    name
    |> mix_exs_path()
    |> File.write(mix(name, opts, spec))

    :ok
  end

  @spec config_exs_path(atom) :: binary
  defp config_exs_path(name), do: "/tmp/#{name}-config.exs"

  @spec mix_exs_path(atom) :: binary
  defp mix_exs_path(name), do: "/tmp/#{name}-mix.exs"

  @spec config(keyword) :: binary
  defp config(spec) do
    spec
    |> Keyword.get(:code_paths, [])
    |> List.wrap()
    |> Enum.map(fn dir ->
      Path.wildcard("#{dir}/config.exs")
    end)
    |> List.flatten()
    |> case do
      [config] -> File.read!(config)
      [] -> File.read!(@emptyconfig)
    end
  end

  @spec mix(atom, [atom | keyword], keyword) :: term
  defp mix(name, opts, spec) do
    config = Mix.Project.config()

    project =
      config
      |> Keyword.take([:version, :elixir])
      |> Keyword.put(:app, :void)
      |> Keyword.put(:config_path, @emptyconfig)
      |> Keyword.put(:elixirc_paths, elixirc_paths(spec))
      |> Keyword.put(:deps, deps(config, opts))

    "../ex_united/mix.exs.eex"
    |> Path.expand(__ENV__.file)
    |> EEx.eval_file(
      project: project,
      all_env: read_config(name),
      supervised: supervised(spec)
    )
  end

  @spec elixirc_paths(keyword) :: list
  defp elixirc_paths(spec) do
    Keyword.get(spec, :code_paths, [])
  end

  @spec deps(keyword, [atom | keyword]) :: list
  defp deps(config, opts) do
    exclude =
      opts
      |> Keyword.get(:exclude)
      |> List.wrap()
      |> Kernel.++(@excluded_dependencies)

    config
    |> Keyword.get(:deps)
    |> Kernel.++([{Keyword.get(config, :app), path: File.cwd!()}])
    |> Enum.reject(fn dep ->
      Enum.member?(exclude, elem(dep, 0))
    end)
  end

  defp read_config(name) do
    if function_exported?(Config.Reader, :read!, 1) do
      Config.Reader
    else
      Mix.Config
    end
    |> apply(:read!, [config_exs_path(name)])
  end

  @spec supervised(keyword) :: binary
  defp supervised(spec) do
    case Keyword.get(spec, :supervise) do
      nil ->
        "[]"

      children ->
        Macro.to_string(children)
    end
  end

  @spec spawn_node(atom, [atom]) :: UNoded.t()
  defp spawn_node(name, opts) do
    captain = Node.self()
    node = :"#{name}@#{@nodehost}"

    connect =
      unless Enum.member?(opts, :connect) do
        " --erl '-connect_all false'"
      end

    env = [MIX_EXS: mix_exs_path(name)]

    out =
      if Enum.member?(opts, :verbose) do
        IO.stream(:stdio, :line)
      end

    command = ~s[iex --name #{node}#{connect} -S mix run -e 'Node.connect(#{inspect(captain)})']

    %{pid: pid} =
      Porcelain.spawn_shell(
        command,
        env: env,
        out: out
      )

    await_node(node)

    if Enum.member?(opts, :connect) do
      [last | others] = Node.list() |> Enum.reverse()

      Enum.each(others, fn node ->
        :rpc.call(last, Node, :connect, [node])
      end)
    end

    %UNoded{node: node, pid: pid, command: command, env: env}
  end

  @spec await_node(node) :: :ok
  defp await_node(node) do
    unless Enum.member?(Node.list(), node) do
      Process.sleep(100)
      await_node(node)
    end

    :ok
  end
end
