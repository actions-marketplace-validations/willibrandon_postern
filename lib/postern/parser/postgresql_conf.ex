defmodule Postern.Parser.PostgresqlConf do
  @moduledoc """
  Parser for `postgresql.conf` and `postgresql.auto.conf`.

  Grammar (PostgreSQL docs):

  * `name = value` or `name value` — `=` is optional, whitespace is ignored
  * `value` may be quoted with `''` escaping (`''` inside `'...'` means `'`)
  * units like `8MB`, `30s`, `2min` are part of the value
  * booleans have many spellings (`on`/`off`, `true`/`false`, `yes`/`no`, `1`/`0`)
  * `#` starts a comment (unless inside a quoted value)
  * directives `include`, `include_if_exists`, `include_dir` — resolved relative to file
  * later entries override earlier ones
  * every token carries `{line, col}`-span
  """

  import NimbleParsec

  # Whitespace
  opt_whitespace = ascii_string([?\s, ?\t], min: 0)

  # Identifier: setting name — letters, digits, underscore, dot, dash
  # We allow any run of these; validation is performed by the diagnostics layer.
  identifier =
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?-], min: 1)
    |> label("setting name")

  # Quoted string: '...' with '' => '
  # Inside we allow any char except single quote, or '' as escaped.
  quoted_content =
    repeat(
      choice([
        string("''") |> replace("'"),
        utf8_string([not: ?'], min: 1)
      ])
    )
    |> reduce({Enum, :join, [""]})

  quoted_string =
    ignore(string("'"))
    |> concat(quoted_content)
    |> ignore(string("'"))
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:quoted)

  # Unquoted value: one token up to whitespace or # or '
  # For postgresql.conf the value is a single token (quoted or unquoted)
  unquoted_value =
    ascii_string([not: ?\s, not: ?\t, not: ?#, not: ?", not: ?'], min: 1)
    |> label("value")

  # Value: quoted or unquoted
  value =
    choice([
      quoted_string,
      unquoted_value |> unwrap_and_tag(:unquoted)
    ])

  # Assignment: name [ = ] value
  # We capture raw name and value strings for spans via post_traverse later.
  assignment_core =
    identifier
    |> ignore(opt_whitespace)
    |> ignore(optional(string("=")))
    |> ignore(opt_whitespace)
    |> concat(value)

  # We define line parsers as combinators, but actual file parsing is line-by-line
  # in Elixir for accurate line/col tracking. The combinators below are used for
  # tokenisation.
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_quoted, quoted_string)
  defparsec(:parse_value, value)
  defparsec(:parse_assignment_core, assignment_core)

  @type span :: %{
          line: pos_integer(),
          col: pos_integer(),
          end_line: pos_integer(),
          end_col: pos_integer()
        }
  @type entry ::
          %{
            type: :assignment,
            name: String.t(),
            value: String.t(),
            raw_value: String.t(),
            quoted: boolean(),
            span: span(),
            name_span: span(),
            value_span: span(),
            raw: String.t()
          }
          | %{
              type: :include,
              directive: String.t(),
              file: String.t(),
              quoted: boolean(),
              span: span(),
              raw: String.t()
            }
          | %{type: :blank, span: span(), raw: String.t()}
          | %{type: :comment, text: String.t(), span: span(), raw: String.t()}
          | %{type: :error, message: String.t(), span: span(), raw: String.t()}

  @include_directives ~w(include include_if_exists include_dir)

  @doc """
  Parses a `postgresql.conf` file content.

  Returns `{:ok, entries}` where `entries` is a list of entries with spans.
  Parse errors are represented as `{:error, ...}` entries, not as a top-level error,
  so the file always parses.
  """
  @spec parse(String.t()) :: {:ok, [entry()]}
  def parse(content) when is_binary(content) do
    lines = String.split(content, "\n", trim: false)

    entries =
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {raw_line, line_no} ->
        # Keep raw without \r for round-trip, but remember original for spans (we use raw_line without \r)
        line = String.trim_trailing(raw_line, "\r")
        parse_line(line, line_no)
      end)

    {:ok, entries}
  end

  @doc """
  Parses a single line with known line number.
  """
  @spec parse_line(String.t(), pos_integer()) :: entry()
  def parse_line(line, line_no) when is_binary(line) and is_integer(line_no) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        %{type: :blank, span: span_for(line_no, 1, line), raw: line}

      String.starts_with?(trimmed, "#") ->
        col = column_of(line, "#")
        %{type: :comment, text: line, span: span_for(line_no, col, line), raw: line}

      true ->
        # Strip trailing comment not inside quotes, then parse the code part
        {code_part, comment_part} = split_comment(line)

        code_trimmed = String.trim(code_part)

        if code_trimmed == "" do
          # line was only whitespace + comment, treat as comment
          %{type: :comment, text: line, span: span_for(line_no, 1, line), raw: line}
        else
          parse_code(code_trimmed, line, line_no, comment_part)
        end
    end
  end

  defp parse_code(code_trimmed, raw_line, line_no, _comment) do
    case parse_assignment_core(code_trimmed) do
      {:ok, [name, {tag, val}], rest, %{}, _, _} when tag in [:quoted, :unquoted] ->
        parse_assignment(name, tag, val, rest, raw_line, line_no)

      {:error, reason, _rest, _, _, _} ->
        parse_error(reason, raw_line, line_no)

      _ ->
        parse_error("could not parse line", raw_line, line_no)
    end
  end

  defp parse_assignment(name, tag, value, rest, raw_line, line_no) do
    if String.trim(rest) == "" do
      assignment_entry(name, tag, value, raw_line, line_no)
    else
      parse_error_at(
        "unexpected trailing content: #{inspect(rest)}",
        raw_line,
        line_no,
        column_of(raw_line, rest)
      )
    end
  end

  defp assignment_entry(name, tag, value, raw_line, line_no) do
    quoted = tag == :quoted
    raw_value = if quoted, do: "'#{String.replace(value, "'", "''")}'", else: value
    span = span_for(line_no, 1, raw_line)

    if name in @include_directives do
      %{
        type: :include,
        directive: name,
        file: value,
        quoted: quoted,
        span: span,
        file_span: value_span_for(raw_line, raw_value, line_no),
        raw: raw_line
      }
    else
      %{
        type: :assignment,
        name: name,
        value: value,
        raw_value: raw_value,
        quoted: quoted,
        span: span,
        name_span: span_for_token(raw_line, name, line_no),
        value_span: value_span_for(raw_line, raw_value, line_no),
        raw: raw_line
      }
    end
  end

  defp parse_error(message, raw_line, line_no) do
    %{type: :error, message: message, span: span_for(line_no, 1, raw_line), raw: raw_line}
  end

  defp parse_error_at(message, raw_line, line_no, col) do
    %{type: :error, message: message, span: span_for(line_no, col, raw_line), raw: raw_line}
  end

  defp split_comment(line) do
    # Walk line char by char, tracking if inside single-quoted string
    # '' inside quotes is escaped, not a terminator.
    do_split(line, "", false, 0)
  end

  defp do_split("", acc, _in_quote, _i), do: {acc, nil}

  defp do_split(<<c::utf8, rest::binary>>, acc, in_quote, _i) when c == ?' do
    # Check for '' escape when in_quote
    case rest do
      <<"'", rest2::binary>> when in_quote ->
        # escaped quote, stay in quote
        do_split(rest2, acc <> "''", true, 0)

      _ ->
        # toggle quote state
        do_split(rest, acc <> "'", !in_quote, 0)
    end
  end

  defp do_split(<<c::utf8, rest::binary>>, acc, false, _i) when c == ?# do
    # comment start outside quote
    {acc, "#" <> rest}
  end

  defp do_split(<<c::utf8, rest::binary>>, acc, in_quote, _i) do
    do_split(rest, acc <> <<c::utf8>>, in_quote, 0)
  end

  defp span_for(line, col, raw) do
    # end col is col + byte_size of raw (approx)
    end_col = col + String.length(raw)
    %{line: line, col: col, end_line: line, end_col: end_col}
  end

  defp span_for_token(raw_line, token, line_no) do
    col = column_of(raw_line, token)
    end_col = col + String.length(token)
    %{line: line_no, col: col, end_line: line_no, end_col: end_col}
  end

  defp value_span_for(raw_line, raw_value, line_no) do
    # Find last occurrence of raw_value in raw_line (to handle duplicate names)
    # Use :binary.match with reverse? Simple: find via String.contains and column_of
    # If not found (e.g., quoted vs unquoted mismatch), approximate
    col =
      case :binary.match(raw_line, raw_value) do
        {pos, _len} -> pos + 1
        :nomatch -> column_of(raw_line, raw_value)
      end

    end_col = col + String.length(raw_value)
    %{line: line_no, col: col, end_line: line_no, end_col: end_col}
  end

  defp column_of(line, substr) when is_binary(substr) do
    case :binary.match(line, substr) do
      {pos, _} -> pos + 1
      :nomatch -> 1
    end
  end

  # Public helpers for diagnostics (expose include directives list)
  def include_directives, do: @include_directives
end
