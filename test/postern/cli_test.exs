defmodule Postern.CLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Postern.CLI

  @fixtures Path.expand("../fixtures", __DIR__)

  test "check returns zero for a valid PostgreSQL configuration" do
    output =
      capture_io(fn ->
        assert CLI.run(["check", Path.join(@fixtures, "postgresql.conf")]) == 0
      end)

    assert output =~ "requires restart"
  end

  test "check returns one for parser errors" do
    path = invalid_config_path()

    output =
      capture_io(fn ->
        assert CLI.run(["check", path]) == 1
      end)

    assert output =~ "error"
  end

  test "check --json emits machine-readable diagnostics" do
    path = invalid_config_path()

    output =
      capture_io(fn ->
        assert CLI.run(["check", "--json", path]) == 1
      end)

    assert [%{"file" => _, "diagnostics" => [%{"message" => _}]}] = Jason.decode!(output)
  end

  defp invalid_config_path do
    directory = Path.join(System.tmp_dir!(), "postern-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    path = Path.join(directory, "postgresql.conf")
    File.write!(path, File.read!(Path.join(@fixtures, "invalid_postgresql.conf")))
    path
  end
end
