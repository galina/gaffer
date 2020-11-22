defmodule GafferTest do
  use ExUnit.Case
  doctest Gaffer

  test "greets the world" do
    assert Gaffer.hello() == :world
  end
end
