defmodule Postern.Diagnostics do
  @moduledoc """
  Produces LSP diagnostics from file contents.

  Parse errors are handled for all three file formats. PostgreSQL configuration
  assignments additionally use generated catalogs for offline validation.
  """

  alias GenLSP.Enumerations.DiagnosticSeverity
  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range
  alias Postern.FileKind
  alias Postern.Parser.PgHba
  alias Postern.Parser.PgIdent

  @source "postern"

  @doc """
  Returns diagnostics for the given `uri` and `text`.

  The file kind is detected from the URI via `Postern.FileKind`.
  """
  @spec for_document(String.t(), String.t(), map() | keyword()) :: [Diagnostic.t()]
  def for_document(uri, text, initialization_options \\ %{})
      when is_binary(uri) and is_binary(text) do
    kind = FileKind.detect(uri)

    case kind do
      :postgresql_conf ->
        Postern.PostgresqlConfDiagnostics.diagnostics(text, initialization_options)

      :pg_hba_conf ->
        pg_hba_diagnostics(text)

      :pg_ident_conf ->
        pg_ident_diagnostics(text)

      :unknown ->
        []
    end
  end

  defp pg_hba_diagnostics(text) do
    {:ok, entries} = PgHba.parse(text)

    entries
    |> Enum.filter(&(&1.type == :error))
    |> Enum.map(fn entry ->
      %Diagnostic{
        range: span_to_range(entry.span),
        severity: DiagnosticSeverity.error(),
        source: @source,
        message: entry.message
      }
    end)
  end

  defp pg_ident_diagnostics(text) do
    {:ok, entries} = PgIdent.parse(text)

    entries
    |> Enum.filter(&(&1.type == :error))
    |> Enum.map(fn entry ->
      %Diagnostic{
        range: span_to_range(entry.span),
        severity: DiagnosticSeverity.error(),
        source: @source,
        message: entry.message
      }
    end)
  end

  defp span_to_range(%{line: line, col: col, end_line: end_line, end_col: end_col}) do
    %Range{
      start: %Position{line: line - 1, character: col - 1},
      end: %Position{line: end_line - 1, character: end_col - 1}
    }
  end

  defp span_to_range(%{line: line, col: col}) do
    %Range{
      start: %Position{line: line - 1, character: col - 1},
      end: %Position{line: line - 1, character: col}
    }
  end
end
