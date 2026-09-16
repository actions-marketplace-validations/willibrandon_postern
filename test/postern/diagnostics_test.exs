defmodule Postern.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias Postern.Diagnostics

  @fixtures Path.expand("../fixtures", __DIR__)

  test "parser errors become diagnostics with the exact source line span" do
    cases = [
      {"invalid_postgresql.conf", "file:///tmp/postgresql.conf", 0, 0, 6},
      {"invalid_pg_hba.conf", "file:///tmp/pg_hba.conf", 0, 0, 12},
      {"invalid_pg_ident.conf", "file:///tmp/pg_ident.conf", 0, 0, 21}
    ]

    for {fixture, uri, line, start_character, end_character} <- cases do
      text = fixture!(fixture)

      assert [%{range: range, severity: 1, source: "postern"}] =
               Diagnostics.for_document(uri, text)

      assert range.start.line == line
      assert range.start.character == start_character
      assert range.end.line == line
      assert range.end.character == end_character
    end
  end

  defp fixture!(name) do
    @fixtures
    |> Path.join(name)
    |> File.read!()
  end
end
