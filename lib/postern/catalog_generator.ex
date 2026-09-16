defmodule Postern.CatalogGenerator do
  @moduledoc """
  Generates versioned PostgreSQL setting catalogs from live PostgreSQL servers.

  The generator deliberately selects the complete `pg_settings` fields required
  by Postern instead of embedding setting metadata in source code. A generated
  catalog is a JSON object containing its PostgreSQL major version and a list of
  setting maps.
  """

  @select """
  select name, vartype, unit, context, category, short_desc,
         extra_desc, min_val, max_val, enumvals, boot_val, reset_val
    from pg_settings
   order by name
  """

  @default_ports %{13 => 5413, 14 => 5414, 15 => 5415, 16 => 5416, 17 => 5417, 18 => 5418}

  @doc """
  Generates one catalog by querying the PostgreSQL server on `port`.
  """
  @spec generate(pos_integer(), :inet.port_number(), keyword()) :: :ok
  def generate(version, port, opts \\ []) when is_integer(version) and is_integer(port) do
    database = Keyword.get(opts, :database, "postgres")
    username = Keyword.get(opts, :username, "postgres")
    hostname = Keyword.get(opts, :hostname, "127.0.0.1")
    output_dir = Keyword.get(opts, :output_dir, "priv/catalog")

    {:ok, connection} =
      Postgrex.start_link(
        hostname: hostname,
        port: port,
        database: database,
        username: username,
        password: "",
        connect_timeout: 5_000,
        timeout: 15_000
      )

    try do
      case Postgrex.query(connection, @select, [], query_type: :text) do
        {:ok, result} ->
          settings =
            Enum.map(result.rows, fn row ->
              result.columns
              |> Enum.zip(row)
              |> Map.new()
            end)

          catalog = %{"version" => version, "settings" => settings}
          path = Path.join(output_dir, "pg#{version}.json")

          File.mkdir_p!(output_dir)
          File.write!(path, Jason.encode!(catalog, pretty: true) <> "\n")
          :ok

        {:error, error} ->
          raise "catalog query failed for PostgreSQL #{version} on port #{port}: #{Exception.message(error)}"
      end
    after
      GenServer.stop(connection, :normal)
    end
  end

  @doc """
  Returns the default major-version-to-port mapping used by the Mix task.
  """
  @spec default_ports() :: %{pos_integer() => :inet.port_number()}
  def default_ports, do: @default_ports

  @doc """
  Generates all catalogs using the default ports 5413 through 5418.
  """
  @spec generate_all(keyword()) :: :ok
  def generate_all(opts \\ []) do
    Enum.each(@default_ports, fn {version, port} ->
      generate(version, port, opts)
    end)

    :ok
  end
end
