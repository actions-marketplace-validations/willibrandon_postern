defmodule Postern.FeaturesTest do
  use ExUnit.Case, async: true

  alias GenLSP.Structures.Position
  alias Postern.Features

  test "hover on a setting reads generated catalog documentation" do
    text = "shared_buffers = 128MB\n"
    position = %Position{line: 0, character: 7}

    assert %{contents: %{kind: "markdown", value: value}, range: range} =
             Features.hover("file:///tmp/postgresql.conf", text, position, %{"pg" => 16})

    assert value =~ "shared_buffers"
    assert value =~ "Sets the number of shared memory buffers"
    assert value =~ "integer"
    assert value =~ "postmaster"
    assert range.start.character == 0
  end

  test "postgresql.conf completion offers setting names and enum values" do
    name_items =
      Features.completion(
        "file:///tmp/postgresql.conf",
        "shared_",
        %Position{line: 0, character: 7},
        %{"pg" => 16}
      ).items

    assert Enum.any?(name_items, &(&1.label == "shared_buffers"))

    value_items =
      Features.completion(
        "file:///tmp/postgresql.conf",
        "password_encryption = scr",
        %Position{line: 0, character: 26},
        %{"pg" => 16}
      ).items

    assert Enum.any?(value_items, &(&1.label == "scram-sha-256"))
  end

  test "pg_hba.conf completion offers address keywords and methods" do
    address_items =
      Features.completion(
        "file:///tmp/pg_hba.conf",
        "host all all ",
        %Position{line: 0, character: 14}
      ).items

    assert Enum.any?(address_items, &(&1.label == "samehost"))
    assert Enum.any?(address_items, &(&1.label == "samenet"))

    method_items =
      Features.completion(
        "file:///tmp/pg_hba.conf",
        "host all all 10.0.0.0/8 ",
        %Position{line: 0, character: 25}
      ).items

    assert Enum.any?(method_items, &(&1.label == "scram-sha-256"))
    assert Enum.any?(method_items, &(&1.label == "reject"))
  end
end
