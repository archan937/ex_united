defmodule ExUnited.Case do
  @moduledoc false

  def send_message(pid_list, message) do
    pid_list
    |> :erlang.list_to_pid()
    |> send(message)
  end

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      import ExUnited.Case, except: [send_message: 2]
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
          defmacro assert({_func, _meta, [left, right]} = ast) do
            assertion(:assert, ast)
          end

          defmacro assert({_, [line: line], _} = ast) do
            exception("assertion", line, ast)
          end

          defmacro refute({_func, _meta, [left, right]} = ast) do
            assertion(:refute, ast)
          end

          defmacro refute({_, [line: line], _} = ast) do
            exception("refutation", line, ast)
          end

          defp assertion(type, {func, _meta, [left, right]}) do
            mod = unquote(__MODULE__)

            left =
              left
              |> Macro.escape()
              |> Macro.postwalk(fn
                {:{}, [], [:^, meta, [{name, _meta, nil}]]} ->
                  {name, meta, nil}

                {:{}, [], [name, meta, nil]} ->
                  {name, meta, nil}

                quoted ->
                  quoted
              end)

            quote do
              :rpc.call(
                __CAPTAIN__,
                unquote(mod),
                :send_message,
                [
                  __PID__,
                  {unquote(type),
                   {unquote(func), [], [unquote(left), Macro.escape(unquote(right))]}}
                ]
              )
            end
          end

          defp exception(type, line, ast) do
            quote do
              raise %CompileError{
                description: "#{unquote(type)} not supported: #{unquote(Macro.to_string(ast))}",
                line: unquote(line)
              }
            end
          end

          def run(binding) do
            unquote({:__block__, [], assigns ++ code})
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

      {:assert, __META__, [true]} =
        quote do
          assert(true)
        end

      for n <- 1..(Process.info(self(), :message_queue_len) |> elem(1)) do
        receive do
          {type, assertion} ->
            Code.eval_quoted({type, __META__, [assertion]})
        end
      end
    end
  end
end
