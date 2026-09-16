defmodule Postern.LiveDiagnostics do
  @moduledoc """
  Maps live PostgreSQL configuration results to source diagnostics.
  """

  alias GenLSP.Structures.Diagnostic
  alias GenLSP.Structures.Position
  alias GenLSP.Structures.Range

  @doc """
  Produces diagnostics from a live snapshot for the open document.
  """
  @spec for_document(String.t(), map() | {:error, atom()} | nil, boolean()) :: [Diagnostic.t()]
  def for_document(uri, snapshot, configured),
    do: for_document(uri, snapshot, configured, :postgresql_conf)

  @spec for_document(String.t(), map() | {:error, atom()} | nil, boolean(), atom()) :: [
          Diagnostic.t()
        ]
  def for_document(_uri, nil, _configured, _kind), do: []
  def for_document(_uri, {:error, :disabled}, _configured, _kind), do: []

  def for_document(_uri, {:error, _reason}, true, _kind) do
    [diagnostic(0, "PostgreSQL server is unreachable; using offline diagnostics", 3)]
  end

  def for_document(_uri, {:error, _reason}, false, _kind), do: []

  def for_document(
        uri,
        %{file_settings: file_settings, settings: settings},
        _configured,
        :postgresql_conf
      ) do
    file_diagnostics =
      file_settings
      |> Enum.filter(fn row ->
        is_binary(row["error"]) and row["error"] != "" and same_file?(row["sourcefile"], uri)
      end)
      |> Enum.map(fn row ->
        diagnostic(row["sourceline"] || 1, row["error"], 1)
      end)

    restart_diagnostics =
      settings
      |> Enum.filter(fn row ->
        truthy?(row["pending_restart"]) and same_file?(row["sourcefile"], uri)
      end)
      |> Enum.map(fn row ->
        diagnostic(
          row["sourceline"] || 1,
          "setting #{inspect(row["name"])} is pending restart",
          3
        )
      end)

    file_diagnostics ++ restart_diagnostics
  end

  def for_document(uri, %{hba_rules: rows}, _configured, :pg_hba_conf),
    do: source_row_diagnostics(rows, uri, "file_name", "line_number")

  def for_document(uri, %{ident_mappings: rows}, _configured, :pg_ident_conf),
    do: source_row_diagnostics(rows, uri, "file_name", "line_number")

  defp source_row_diagnostics(rows, uri, file_key, line_key) do
    Enum.flat_map(rows, fn row ->
      if is_binary(row["error"]) and row["error"] != "" and same_file?(row[file_key], uri) do
        [diagnostic(row[line_key] || 1, row["error"], 1)]
      else
        []
      end
    end)
  end

  defp same_file?(nil, _uri), do: false

  defp same_file?(sourcefile, uri) do
    Path.basename(to_string(sourcefile)) == Path.basename(Postern.FileKind.uri_to_path(uri))
  end

  defp truthy?(value) when value in [true, "t", "true", "on", 1, "1"], do: true
  defp truthy?(_value), do: false

  defp diagnostic(line, message, severity) do
    %Diagnostic{
      range: %Range{
        start: %Position{line: max(line - 1, 0), character: 0},
        end: %Position{line: max(line - 1, 0), character: 0}
      },
      severity: severity,
      source: "postern",
      message: message
    }
  end
end
