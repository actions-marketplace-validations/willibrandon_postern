defmodule Postern.LiveDiagnosticsTest do
  use ExUnit.Case, async: true

  alias Postern.LiveDiagnostics

  test "maps file setting errors and pending restart rows to source diagnostics" do
    snapshot = %{
      file_settings: [
        %{
          "sourcefile" => "/var/lib/postgresql/postgresql.conf",
          "sourceline" => 12,
          "error" => "setting could not be applied"
        }
      ],
      settings: [
        %{
          "name" => "shared_buffers",
          "sourcefile" => "/var/lib/postgresql/postgresql.conf",
          "sourceline" => 12,
          "pending_restart" => "t"
        }
      ]
    }

    diagnostics =
      LiveDiagnostics.for_document("file:///var/lib/postgresql/postgresql.conf", snapshot, true)

    assert Enum.any?(diagnostics, &(&1.message == "setting could not be applied"))
    assert Enum.any?(diagnostics, &String.contains?(&1.message, "pending restart"))
    assert Enum.all?(diagnostics, &(&1.range.start.line == 11))
  end

  test "reports one informational diagnostic when a configured server is unavailable" do
    [diagnostic] =
      LiveDiagnostics.for_document("file:///tmp/postgresql.conf", {:error, :unreachable}, true)

    assert diagnostic.severity == 3
    assert diagnostic.message =~ "offline diagnostics"
  end
end
