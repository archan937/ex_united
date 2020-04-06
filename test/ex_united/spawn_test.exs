defmodule ExUnited.SpawnTest do
  use ExUnit.Case

  import TestHelper

  alias ExUnited.Spawn, as: Simmons
  alias ExUnited.Spawn.State

  setup do
    {:ok, spawned} = ExUnited.spawn([:ryan, :david, :wayne])

    on_exit(fn ->
      ExUnited.teardown()
    end)

    spawned
  end

  test "summons spawns" do
    assert :noop = Simmons.summon(:ryan)

    %State{nodes: nodes} = Simmons.legion()
    assert 3 == Map.keys(nodes) |> length()
  end

  test "keeps track of its legion" do
    assert %State{
             nodes: %{
               ryan: %{node: :"ryan@127.0.0.1", port: _},
               david: %{node: :"david@127.0.0.1", port: _},
               wayne: %{node: :"wayne@127.0.0.1", port: _}
             }
           } = Simmons.legion()
  end

  test "kills a spawned node", spawned do
    [david, _ryan, _wayne] = take(spawned, :node) |> Enum.sort()

    assert :ok = Simmons.kill(:ryan)

    %State{nodes: nodes} = Simmons.legion()
    assert [:david, :wayne] == Map.keys(nodes) |> Enum.sort()

    assert :noop = Simmons.kill(:ryan)

    :rpc.call(david, System, :halt, [])
    Process.sleep(100)

    %State{nodes: nodes} = Simmons.legion()
    assert [:david, :wayne] == Map.keys(nodes) |> Enum.sort()

    assert :noop = Simmons.kill(:david)

    %State{nodes: nodes} = Simmons.legion()
    assert [:wayne] == Map.keys(nodes) |> Enum.sort()
  end

  test "kills all its spawned nodes" do
    Simmons.kill_all()

    %State{nodes: nodes} = Simmons.legion()
    assert [] == Map.keys(nodes) |> Enum.sort()
  end
end
