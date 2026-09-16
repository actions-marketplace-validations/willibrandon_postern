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

  test "maps live HBA and ident rule errors" do
    hba = %{
      hba_rules: [
        %{"file_name" => "/etc/pg_hba.conf", "line_number" => 4, "error" => "invalid address"}
      ],
      ident_mappings: []
    }

    ident = %{
      hba_rules: [],
      ident_mappings: [
        %{"file_name" => "/etc/pg_ident.conf", "line_number" => 7, "error" => "invalid map"}
      ]
    }

    [hba_diagnostic] =
      LiveDiagnostics.for_document("file:///etc/pg_hba.conf", hba, true, :pg_hba_conf)

    [ident_diagnostic] =
      LiveDiagnostics.for_document("file:///etc/pg_ident.conf", ident, true, :pg_ident_conf)

    assert hba_diagnostic.message == "invalid address"
    assert hba_diagnostic.range.start.line == 3
    assert ident_diagnostic.message == "invalid map"
    assert ident_diagnostic.range.start.line == 6
  end
end
