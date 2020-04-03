defmodule ExUnited.SpawnTest do
  use ExUnit.Case

  import TestHelper

  alias ExUnited.Spawn, as: Simmons
  alias ExUnited.Spawn.State

  setup do
    {:ok, spawned} = ExUnited.start([:ryan, :david, :wayne])

    on_exit(fn ->
      teardown()
    end)

    spawned
  end

  test "summons spawns" do
    assert :noop = Simmons.spawn(:"ryan@127.0.0.1", "iex -S mix run")

    %State{nodes: nodes} = Simmons.legion()
    assert 3 == Map.keys(nodes) |> length()
  end

  test "keeps track of its legion" do
    assert %State{
             nodes: %{
               :"ryan@127.0.0.1" => %{port: _},
               :"david@127.0.0.1" => %{port: _},
               :"wayne@127.0.0.1" => %{port: _}
             },
             color_index: 0
           } = Simmons.legion()
  end

  test "kills a spawned node", spawned do
    [david, ryan, wayne] = take(spawned, :node) |> Enum.sort()

    assert :ok = Simmons.kill(ryan)

    %State{nodes: nodes} = Simmons.legion()
    assert [david, wayne] == Map.keys(nodes) |> Enum.sort()

    assert :noop = Simmons.kill(ryan)

    :rpc.call(david, System, :halt, [])
    Process.sleep(100)

    %State{nodes: nodes} = Simmons.legion()
    assert [david, wayne] == Map.keys(nodes) |> Enum.sort()

    assert :noop = Simmons.kill(david)

    %State{nodes: nodes} = Simmons.legion()
    assert [wayne] == Map.keys(nodes) |> Enum.sort()
  end

  test "kills all its spawned nodes" do
    Simmons.kill_all()

    %State{nodes: nodes} = Simmons.legion()
    assert [] == Map.keys(nodes) |> Enum.sort()
  end
end
