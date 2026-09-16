defmodule Postern.PgHbaDiagnosticsTest do
  use ExUnit.Case, async: true

  alias Postern.Diagnostics

  @fixtures Path.expand("../fixtures", __DIR__)

  test "warns when a later rule is shadowed by a broader earlier rule" do
    diagnostics =
      Diagnostics.for_document("file:///tmp/pg_hba.conf", fixture!("pg_hba_shadow.conf"))

    assert [%{severity: 2, message: message, range: range}] =
             Enum.filter(diagnostics, &String.contains?(&1.message, "can never match"))

    assert message =~ "earlier"
    assert range.start.line == 3
  end

  test "validates CIDR, netmask, method options and ident references" do
    diagnostics =
      Diagnostics.for_document(
        "file:///tmp/pg_hba.conf",
        fixture!("pg_hba_invalid.conf"),
        %{pg_ident_text: fixture!("pg_ident_references.conf")}
      )

    messages = Enum.map(diagnostics, & &1.message)
    assert Enum.any?(messages, &String.contains?(&1, "malformed CIDR"))
    assert Enum.any?(messages, &String.contains?(&1, "netmask cannot be used with hostname"))
    assert Enum.any?(messages, &String.contains?(&1, "clientcert is not valid on a local rule"))
    assert Enum.any?(messages, &String.contains?(&1, "ldap options"))
    assert Enum.any?(messages, &String.contains?(&1, "non-local rule"))
    assert Enum.any?(messages, &String.contains?(&1, "does not exist in pg_ident.conf"))
  end

  test "warns for trust and password on host rules" do
    diagnostics =
      Diagnostics.for_document(
        "file:///tmp/pg_hba.conf",
        "host all all 10.0.0.0/8 trust\nhost all all 10.0.0.0/8 password\n"
      )

    advice = Enum.filter(diagnostics, &String.contains?(&1.message, "non-local rule"))
    assert length(advice) == 2
    assert Enum.all?(advice, &(&1.severity == 4))
  end

  test "all does not shadow replication rules" do
    diagnostics =
      Postern.PgHbaDiagnostics.diagnostics(
        "local all all trust\nlocal replication all trust\nhost all all 0.0.0.0/0 trust\nhost replication all 10.0.0.0/8 trust\n"
      )

    refute Enum.any?(diagnostics, &String.contains?(&1.message, "shadows it"))
  end

  test "trust hints can be turned off" do
    diagnostics =
      Postern.PgHbaDiagnostics.diagnostics("host all all all trust\n", nil, %{report_trust: false})

    refute Enum.any?(diagnostics, &String.contains?(&1.message, "non-local rule"))
  end

  test "trust on loopback or samehost rules is not reported" do
    diagnostics =
      Postern.PgHbaDiagnostics.diagnostics(
        "host all all 127.0.0.1/32 trust\nhost all all ::1/128 trust\nhost all all samehost trust\n"
      )

    refute Enum.any?(diagnostics, &String.contains?(&1.message, "non-local rule"))
  end

  test "reject rules shadow every later matching rule" do
    text = "host all all 0.0.0.0/0 reject\nhost all all 10.0.0.0/8 scram-sha-256\n"
    diagnostics = Diagnostics.for_document("file:///tmp/pg_hba.conf", text)

    assert Enum.any?(diagnostics, &String.contains?(&1.message, "earlier reject rule"))
  end

  defp fixture!(name) do
    @fixtures
    |> Path.join(name)
    |> File.read!()
  end
end
