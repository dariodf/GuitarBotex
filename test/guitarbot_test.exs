defmodule GuitarBotTest do
  use ExUnit.Case
  doctest GuitarBot

  test "greets the world" do
    assert GuitarBot.hello() == :world
  end
end
