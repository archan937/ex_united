defmodule ExUnited do
  @moduledoc false

  @nodename :captain
  @nodehost '127.0.0.1'

  @emptyconfig Path.expand(
                 "../ex_united/config.exs",
                 __ENV__.file
               )

  alias Porcelain.Process, as: Porcess

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

        generate_files(name, spec)
        {name, spawn_node(name, opts)}
      end)
      |> Enum.into(%{})

    {:ok, spawned}
  end

  def stop(spawned) do
    Enum.each(spawned, fn {_name, %{pid: pid}} ->
      process = %Porcess{pid: pid}

      if Porcess.alive?(process) do
        Porcess.stop(process)
      end
    end)
  end

  defp generate_files(name, spec) do
    name
    |> config_exs_path()
    |> File.write(config(spec))

    name
    |> mix_exs_path()
    |> File.write(mix(name, spec))
  end

  defp config_exs_path(name), do: "/tmp/#{name}-config.exs"
  defp mix_exs_path(name), do: "/tmp/#{name}-mix.exs"

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

  defp mix(name, spec) do
    project =
      Mix.Project.config()
      |> Keyword.take([:version, :elixir])
      |> Keyword.put(:app, :void)
      |> Keyword.put(:config_path, @emptyconfig)
      |> Keyword.put(:elixirc_paths, elixirc_paths(spec))
      |> Keyword.put(:deps, deps())

    "../ex_united/mix.exs.eex"
    |> Path.expand(__ENV__.file)
    |> EEx.eval_file(
      project: project,
      config_exs_path: config_exs_path(name),
      supervised: supervised(spec)
    )
  end

  defp elixirc_paths(spec) do
    Keyword.get(spec, :code_paths, [])
  end

  defp deps do
    Mix.Project.config()
    |> Keyword.get(:deps)
    |> Enum.reject(fn dep ->
      elem(dep, 0) == :porcelain
    end)
  end

  defp supervised(spec) do
    case Keyword.get(spec, :supervise) do
      nil ->
        "[]"

      children ->
        quote do
          (unquote_splicing([children]))
        end
        |> Macro.postwalk(fn
          {:quote, _metadata, children} -> children
          quoted -> quoted
        end)
        |> Macro.to_string()
    end
  end

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

    %{node: node, pid: pid, command: command, env: env}
  end

  defp await_node(node) do
    unless Enum.member?(Node.list(), node) do
      Process.sleep(100)
      await_node(node)
    end
  end
end
