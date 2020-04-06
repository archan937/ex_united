defmodule ExUnited.Case do
  @moduledoc """
  This module makes it possible to seemlessly execute assertions and refutations
  within spawned nodes.

  You can setup your test module by either using `ExUnited.Case` instead of
  `ExUnit.Case`:

      defmodule MyNodesTest do
        use ExUnited.Case
      end

  Or by importing the `ExUnited.Case` module:

      defmodule MyNodesTest do
        use ExUnit.Case
        import ExUnited.Case
      end

  Writing assertions and refutations within the context of a certain spawned is
  pretty straight forward with the use of the `ExUnited.Case.as_node/2` function:

  ## Example

      defmodule MyNodesTest do
        use ExUnited.Case

        setup do
          {:ok, spawned} = ExUnited.spawn([:bruce, :clark])

          on_exit(fn ->
            ExUnited.teardown()
          end)

          spawned
        end

        test "assertions and refutations within node contexts", spawned do
          bruce = get_in(spawned, [:bruce, :node])

          as_node(bruce) do
            assert :"bruce@127.0.0.1" = Node.self()
            refute :"clark@127.0.0.1" == Node.self()
          end

          as_node(:clark) do
            assert :"clark@127.0.0.1" = Node.self()
            refute :"bruce@127.0.0.1" == Node.self()
          end
        end
      end

  See `ExUnited.Case.as_node/2` for more information.
  """

  @doc false
  def send_error(pid_list, message) do
    pid_list
    |> :erlang.list_to_pid()
    |> send(message)
  end

  @doc """
  Injects `use ExUnit.Case` and `import ExUnited.Case, except: [send_error: 2]`
  in the test module.

  Gets triggered after having put `use ExUnited.Case` in your test module.
  """
  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      import ExUnited.Case, except: [send_error: 2]
    end
  end

  @doc """
  A convenience macro function for writing assertions and refutations from within
  spawned nodes.

  It makes writing tests so much easier and more readable. The function accepts
  the following:

    * `node` - the simple name (used during spawning) or the node name
    * `binding` - a keyword list containing variables which will be available
      in the code block (optional)
    * `block` - the code block containing assertions and/or refutations

  ## Example

      test "assertions and refutations within the right context", spawned do
        clark = get_in(spawned, [:clark, :node])
        bruce = get_in(spawned, [:bruce, :node])

        assert :"captain@127.0.0.1" == Node.self()
        assert [:"bruce@127.0.0.1", :"clark@127.0.0.1"] = Node.list() |> Enum.sort()

        as_node(clark) do
          nodes = Node.list()
          refute :"captain@127.0.0.1" == Node.self()
          assert :"clark@127.0.0.1" = Node.self()
          assert [:"captain@127.0.0.1"] = Node.list()
          assert ^nodes = Node.list()
        end

        as_node(:bruce, spawned_node: bruce) do
          assert :"bruce@127.0.0.1" = Node.self()
          assert :"bruce@127.0.0.1" = spawned_node
          assert ^spawned_node = Node.self()
          assert ^spawned_node = :"bruce@127.0.0.1"
          assert [:"captain@127.0.0.1"] = Node.list()
        end
      end
  """
  defmacro as_node(node, binding \\ [], do: block) do
    quoted = generate_module(binding, block)

    quote do
      quoted =
        unquote(Macro.escape(quoted))
        |> Macro.postwalk(fn
          {:__CAPTAIN__, [], _} -> Node.self()
          {:__PID__, [], _} -> :erlang.pid_to_list(self())
          quoted -> quoted
        end)

      node =
        get_in(ExUnited.Spawn.legion(), [:nodes, unquote(node), :node]) ||
          unquote(node)

      case :rpc.call(node, Code, :eval_quoted, [quoted]) do
        {:badrpc, {:EXIT, {error, _}}} ->
          raise(error)

        {:badrpc, :nodedown} ->
          raise(RuntimeError,
            message: "node #{inspect(unquote(node))} seems to be unreachable"
          )

        _ ->
          nil
      end

      :rpc.call(node, ExUnitedBlock, :run, [unquote(binding)])

      message_count =
        self()
        |> Process.info(:message_queue_len)
        |> elem(1)

      if message_count > 0 do
        for n <- 0..message_count do
          receive do
            error ->
              raise error
          end
        end
      end
    end
  end

  @spec generate_module(keyword, list) :: {:__block__, list, list}
  defp generate_module(binding, block) do
    assigns =
      Enum.map(binding, fn {name, _value} ->
        quote do
          unquote({name, [], nil}) = Keyword.get(binding, unquote(name))
        end
      end)

    code =
      case block do
        {:__block__, [], lines} -> lines
        line -> [line]
      end

    quote do
      :code.purge(ExUnitedBlock)
      :code.delete(ExUnitedBlock)

      defmodule ExUnitedBlock do
        @moduledoc false
        import ExUnit.Assertions

        def run(binding) do
          unquote({:__block__, [], assigns ++ code})
        rescue
          error ->
            :rpc.call(__CAPTAIN__, unquote(__MODULE__), :send_error, [
              __PID__,
              error
            ])
        end
      end
    end
  end
end
