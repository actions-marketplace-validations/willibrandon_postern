defmodule Postern.LiveFeaturesTest do
  use ExUnit.Case, async: true

  alias Postern.LiveFeatures

  test "returns effective value and pending restart hints" do
    snapshot = %{
      settings: [
        %{"name" => "port", "setting" => "5433", "pending_restart" => "f"},
        %{"name" => "shared_buffers", "setting" => "16384", "pending_restart" => "t"}
      ]
    }

    hints = LiveFeatures.inlay_hints("port = 5432\nshared_buffers = 128MB\n", snapshot)

    assert Enum.any?(hints, &(&1.label == " = 5433"))
    assert Enum.any?(hints, &(&1.label == " pending restart"))
  end

  test "returns the three live code actions" do
    actions = LiveFeatures.code_actions("file:///tmp/postgresql.conf", %{settings: []})
    titles = Enum.map(actions, & &1.title)

    assert titles == [
             "Apply with ALTER SYSTEM SET",
             "Run pg_reload_conf()",
             "Show effective value"
           ]
  end
end
