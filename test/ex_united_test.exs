defmodule ExUnitedTest do
  use ExUnit.Case
  doctest ExUnited

  test "greets the world" do
    assert ExUnited.hello() == :world
  end
end
