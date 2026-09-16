defmodule Postern.PgIdentDiagnosticsTest do
  use ExUnit.Case, async: true

  alias Postern.Diagnostics

  @fixtures Path.expand("../fixtures", __DIR__)

  test "warns when a map is never referenced by pg_hba.conf" do
    diagnostics =
      Diagnostics.for_document(
        "file:///tmp/pg_ident.conf",
        fixture!("pg_ident_references.conf"),
        %{pg_hba_text: "host all all 10.0.0.0/8 ident map=used_map\n"}
      )

    assert [%{severity: 2, message: "ident map \"unused_map\" is never referenced"}] = diagnostics
  end

  defp fixture!(name) do
    @fixtures
    |> Path.join(name)
    |> File.read!()
  end
end
