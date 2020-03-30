defmodule ExUnited.Case do
  @moduledoc false

  def send_error(pid_list, message) do
    pid_list
    |> :erlang.list_to_pid()
    |> send(message)
  end

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      import ExUnited.Case, except: [send_error: 2]
    end
  end

  defmacro ex_node(node, binding \\ [], do: block) do
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

    quoted =
      quote do
        :code.purge(ExUnitedBlock)
        :code.delete(ExUnitedBlock)

        defmodule ExUnitedBlock do
          import ExUnit.Assertions

          def run(binding) do
            try do
              unquote({:__block__, [], assigns ++ code})
            rescue
              error ->
                :rpc.call(
                  __CAPTAIN__,
                  unquote(__MODULE__),
                  :send_error,
                  [__PID__, error]
                )
            end
          end
        end
      end

    quote do
      quoted =
        unquote(Macro.escape(quoted))
        |> Macro.postwalk(fn
          {:__CAPTAIN__, [], _} -> Node.self()
          {:__PID__, [], _} -> :erlang.pid_to_list(self())
          quoted -> quoted
        end)

      case :rpc.call(unquote(node), Code, :eval_quoted, [quoted]) do
        {:badrpc, {:EXIT, {error, _}}} -> raise(error)
        _ -> nil
      end

      :rpc.call(unquote(node), ExUnitedBlock, :run, [unquote(binding)])

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
end
