defmodule Postern.FileKind do
  @moduledoc """
  Detects the kind of PostgreSQL configuration file based on its basename.

  Known kinds:

  * `:postgresql_conf` - `postgresql.conf` or `postgresql.auto.conf`
  * `:pg_hba_conf` - `pg_hba.conf`
  * `:pg_ident_conf` - `pg_ident.conf`
  * `:unknown` - anything else
  """

  @type t :: :postgresql_conf | :pg_hba_conf | :pg_ident_conf | :unknown

  @doc """
  Detects the file kind from a URI or file path.

  ## Examples

      iex> Postern.FileKind.detect("file:///etc/postgresql/postgresql.conf")
      :postgresql_conf

      iex> Postern.FileKind.detect("/var/lib/pg_hba.conf")
      :pg_hba_conf

  """
  @spec detect(String.t()) :: t()
  def detect(uri_or_path) when is_binary(uri_or_path) do
    basename =
      uri_or_path
      |> uri_to_path()
      |> Path.basename()

    case basename do
      "postgresql.conf" -> :postgresql_conf
      "postgresql.auto.conf" -> :postgresql_conf
      "pg_hba.conf" -> :pg_hba_conf
      "pg_ident.conf" -> :pg_ident_conf
      _ -> :unknown
    end
  end

  @doc """
  Converts a `file://` URI to a filesystem path. If the input is not a URI,
  it is returned unchanged.
  """
  @spec uri_to_path(String.t()) :: String.t()
  def uri_to_path("file://" <> rest) do
    # Handle file:// URI with possible triple slash file:///path
    # URI parsing decodes percent-encoding for us
    case URI.parse("file://" <> rest) do
      %URI{path: path} when is_binary(path) -> URI.decode(path)
      _ -> rest
    end
  end

  def uri_to_path(path), do: path
end
