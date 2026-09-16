defmodule Postern.LiveOracleTest do
  use ExUnit.Case, async: true

  alias Postern.LiveOracle

  test "is disabled without connection configuration and never raises" do
    {:ok, oracle} = LiveOracle.start_link(nil)

    assert LiveOracle.status(oracle) == :disabled
    assert LiveOracle.snapshot(oracle) == {:error, :disabled}
  end

  defmodule SnapshotStub do
    use GenServer

    def init(snapshot), do: {:ok, snapshot}
    def handle_call(:snapshot, _from, snapshot), do: {:reply, {:ok, snapshot}, snapshot}
  end

  test "snapshot unwraps the oracle's reply into the map the features expect" do
    snapshot = %{settings: [], file_settings: [], hba_rules: [], ident_mappings: []}
    {:ok, stub} = GenServer.start_link(SnapshotStub, snapshot)

    assert LiveOracle.snapshot(stub) == snapshot
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
