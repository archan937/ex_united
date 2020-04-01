defmodule ExUnited.CaseTest do
  use ExUnited.Case

  import TestHelper

  setup do
    {:ok, spawned} =
      ExUnited.start(david: [code_paths: ["test/nodes/beckham"], supervise: [David]])

    on_exit(fn ->
      teardown()
    end)

    spawned
  end

  test "executes code in spawned node", spawned do
    [david] = take(spawned, :node)

    ex_node(david, node: david) do
      refute :"captain@127.0.0.1" == Node.self()
      assert :"david@127.0.0.1" = Node.self()
      assert ^node = Node.self()

      refute match?(%{node: ^node}, %{node: :foo})

      assert "The only time you run out of chances is when you stop taking them." = David.talk()

      phrase = "Always have something to look forward to."
      assert ^phrase = David.talk()

      refute phrase == David.talk()

      phrase = David.talk()
      assert "I don't do anything unless I can give it 100%." = phrase
    end

    ex_node(david, spawned_node: david) do
      assert :"david@127.0.0.1" = Node.self()
      assert :"david@127.0.0.1" = spawned_node
      assert ^spawned_node = Node.self()
    end

    try do
      ex_node(david, spawned_node: david) do
        assert spawned_node != Node.self()
      end
    rescue
      error ->
        assert %ExUnit.AssertionError{
                 message: "Assertion with != failed, both sides are exactly equal"
               } = error
    end
  end
end
