defmodule PosternTest do
  use ExUnit.Case
  doctest Postern

  test "module is defined" do
    assert Code.ensure_loaded?(Postern)
  end
end
