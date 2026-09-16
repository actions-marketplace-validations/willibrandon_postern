defmodule Postern.LiveOracle do
  @moduledoc """
  Supervised, reconnecting PostgreSQL live oracle.

  A failed connection is represented as an unavailable oracle. It never raises
  into the language server process and retries with bounded exponential backoff.
  """

  use GenServer

  alias Postern.Parser.PostgresqlConf

  @backoff_start 1_000
  @backoff_max 30_000

  @settings_query """
  select name, setting, unit, context, source, sourcefile, sourceline,
         pending_restart, vartype, enumvals, min_val, max_val, boot_val, reset_val
    from pg_settings
   order by name
  """

  @file_settings_query """
  select name, setting, applied, error, sourcefile, sourceline
    from pg_file_settings
   order by sourceline
  """

  @hba_query """
  select line_number, file_name, error, type, database, user_name, address,
         netmask, auth_method, options
    from pg_hba_file_rules
   order by line_number
  """

  @ident_query """
  select line_number, file_name, map_name, sys_name, pg_username, error
    from pg_ident_file_mappings
   order by line_number
  """

  @database_query "select datname from pg_database where datallowconn order by datname"
  @role_query "select rolname from pg_roles order by rolname"

  @doc "Starts an oracle from PostgreSQL connection options, or disables it for `nil`."
  @spec start_link(keyword() | nil) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @doc "Returns options parsed from initialization options or environment variables."
  @spec connection_options(map() | keyword()) :: keyword() | nil
  def connection_options(options) do
    connection_string =
      option(options, :connection_string) || option(options, :connectionString)

    cond do
      is_binary(connection_string) -> parse_connection_string(connection_string)
      env_configured?() -> environment_options()
      true -> nil
    end
  end

  @doc "Returns the current oracle status."
  @spec status(pid()) :: :disabled | :connecting | :connected | :unreachable
  def status(oracle), do: GenServer.call(oracle, :status)

  @doc "Fetches one consistent live snapshot as a map, or an availability error."
  @spec snapshot(pid()) :: map() | {:error, :disabled | :unreachable}
  def snapshot(oracle) do
    case GenServer.call(oracle, :snapshot, 20_000) do
      {:ok, snapshot} -> snapshot
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Executes one of the live code-action commands."
  @spec execute(pid(), String.t(), list()) :: {:ok, term()} | {:error, atom() | term()}
  def execute(oracle, command, arguments \\ []),
    do: GenServer.call(oracle, {:execute, command, arguments}, 20_000)

  @impl true
  def init(nil),
    do:
      {:ok, %{options: nil, conn: nil, monitor: nil, status: :disabled, backoff: @backoff_start}}

  def init(options) do
    send(self(), :connect)

    {:ok,
     %{options: options, conn: nil, monitor: nil, status: :connecting, backoff: @backoff_start}}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  def handle_call(:snapshot, _from, %{status: status} = state)
      when status in [:disabled, :connecting, :unreachable] do
    {:reply, {:error, (status == :disabled && :disabled) || :unreachable}, state}
  end

  def handle_call(:snapshot, _from, %{conn: conn} = state) do
    {:reply, query_snapshot(conn), state}
  end

  def handle_call({:execute, _command, _arguments}, _from, %{conn: nil} = state) do
    {:reply, {:error, :unreachable}, state}
  end

  def handle_call({:execute, "postern.reloadConfig", _arguments}, _from, %{conn: conn} = state) do
    {:reply, query_scalar(conn, "select pg_reload_conf()"), state}
  end

  def handle_call(
        {:execute, "postern.showEffectiveValue", _arguments},
        _from,
        %{conn: conn} = state
      ) do
    {:reply, query_snapshot(conn), state}
  end

  def handle_call(
        {:execute, "postern.applyAlterSystem", [_uri, text]},
        _from,
        %{conn: conn} = state
      ) do
    {:reply, apply_settings(conn, text), state}
  end

  def handle_call({:execute, _command, _arguments}, _from, state) do
    {:reply, {:error, :unknown_command}, state}
  end

  @impl true
  def handle_info(:connect, %{options: options} = state) do
    case Application.ensure_all_started(:postgrex) do
      {:ok, _started} -> connect(state, options)
      {:error, _reason} -> schedule_retry(state)
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{monitor: monitor} = state) do
    schedule_retry(%{state | conn: nil, monitor: nil, status: :unreachable})
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp connect(state, options) do
    case Postgrex.start_link(options) do
      {:ok, conn} ->
        Process.unlink(conn)
        monitor = Process.monitor(conn)

        {:noreply,
         %{state | conn: conn, monitor: monitor, status: :connected, backoff: @backoff_start}}

      {:error, _reason} ->
        schedule_retry(state)
    end
  end

  defp schedule_retry(%{backoff: backoff} = state) do
    Process.send_after(self(), :connect, backoff)
    {:noreply, %{state | status: :unreachable, backoff: min(backoff * 2, @backoff_max)}}
  end

  defp query_snapshot(conn) do
    with {:ok, settings} <- query_rows(conn, @settings_query),
         {:ok, file_settings} <- query_rows(conn, @file_settings_query) do
      {:ok,
       %{
         settings: settings,
         file_settings: file_settings,
         hba_rules: optional_query(conn, @hba_query),
         ident_mappings: optional_query(conn, @ident_query),
         databases: optional_query(conn, @database_query),
         roles: optional_query(conn, @role_query)
       }}
    else
      {:error, _reason} -> {:error, :unreachable}
    end
  end

  defp optional_query(conn, query) do
    case query_rows(conn, query) do
      {:ok, rows} -> rows
      {:error, _reason} -> []
    end
  end

  defp query_rows(conn, query) do
    case Postgrex.query(conn, query, [], query_type: :text) do
      {:ok, result} ->
        {:ok, Enum.map(result.rows, &Map.new(Enum.zip(result.columns, &1)))}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _error -> {:error, :unreachable}
  catch
    :exit, _reason -> {:error, :unreachable}
  end

  defp query_scalar(conn, query) do
    case Postgrex.query(conn, query, [], query_type: :text) do
      {:ok, %{rows: rows}} -> {:ok, rows}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _error -> {:error, :unreachable}
  catch
    :exit, _reason -> {:error, :unreachable}
  end

  defp apply_settings(conn, text) do
    {:ok, entries} = PostgresqlConf.parse(text)
    Enum.reduce_while(entries, {:ok, []}, &apply_setting(conn, &1, &2))
  rescue
    _error -> {:error, :unreachable}
  catch
    :exit, _reason -> {:error, :unreachable}
  end

  defp apply_setting(conn, %{type: :assignment, name: name, value: value}, {:ok, applied}) do
    if Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_.-]*$/, name) do
      statement = "ALTER SYSTEM SET #{name} = '#{String.replace(value, "'", "''")}'"

      case Postgrex.query(conn, statement, [], query_type: :text) do
        {:ok, _result} -> {:cont, {:ok, [name | applied]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    else
      {:cont, {:ok, applied}}
    end
  end

  defp apply_setting(_conn, _entry, result), do: {:cont, result}

  defp parse_connection_string(string) do
    uri = URI.parse(string)
    {username, password} = parse_userinfo(uri.userinfo)

    [
      hostname: uri.host || "localhost",
      port: uri.port || 5432,
      database: String.trim_leading(uri.path || "/postgres", "/"),
      username: username || System.get_env("PGUSER", "postgres"),
      password: password || System.get_env("PGPASSWORD", "")
    ]
  end

  defp parse_userinfo(nil), do: {nil, nil}

  defp parse_userinfo(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {URI.decode(username), URI.decode(password)}
      [username] -> {URI.decode(username), nil}
    end
  end

  defp environment_options do
    [
      hostname: System.get_env("PGHOST", "localhost"),
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      database: System.get_env("PGDATABASE", "postgres"),
      username: System.get_env("PGUSER", "postgres"),
      password: System.get_env("PGPASSWORD", "")
    ]
  end

  defp env_configured? do
    Enum.any?(~w(PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD), &System.get_env/1)
  end

  defp option(options, key) when is_map(options), do: options[key] || options[Atom.to_string(key)]
  defp option(options, key) when is_list(options), do: Keyword.get(options, key)
  defp option(_options, _key), do: nil
end
