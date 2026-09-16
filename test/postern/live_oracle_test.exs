defmodule Postern.LiveOracleTest do
  use ExUnit.Case, async: true

  alias Postern.LiveOracle

  test "is disabled without connection configuration and never raises" do
    {:ok, oracle} = LiveOracle.start_link(nil)

    assert LiveOracle.status(oracle) == :disabled
    assert LiveOracle.snapshot(oracle) == {:error, :disabled}
  end

  test "parses a connection string without exposing credentials" do
    options =
      LiveOracle.connection_options(%{
        "connectionString" => "postgres://alice:secret@db.example.test:5433/app"
      })

    assert options[:hostname] == "db.example.test"
    assert options[:port] == 5433
    assert options[:database] == "app"
    assert options[:username] == "alice"
    assert options[:password] == "secret"
  end
end
