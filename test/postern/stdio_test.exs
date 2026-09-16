defmodule Postern.StdioTest do
  use ExUnit.Case, async: false

  test "speaks initialize and shutdown over stdio" do
    mix = System.find_executable("mix")

    port =
      Port.open(
        {:spawn_executable, mix},
        [
          :binary,
          :exit_status,
          {:args,
           [
             "run",
             "--no-compile",
             "--no-start",
             "-e",
             "Postern.Application.start(:normal, []); Process.sleep(:infinity)"
           ]},
          {:env, [{~c"MIX_ENV", ~c"dev"}]}
        ]
      )

    on_exit(fn ->
      if Port.info(port), do: Port.close(port)
    end)

    Port.command(
      port,
      packet(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"processId" => nil, "rootUri" => nil, "capabilities" => %{}}
      })
    )

    {response, buffer} = read_packet(port, "")
    assert %{"id" => 1, "result" => %{"capabilities" => capabilities}} = response
    assert capabilities["textDocumentSync"]["openClose"]

    Port.command(port, packet(%{"jsonrpc" => "2.0", "id" => 2, "method" => "shutdown"}))
    {response, _buffer} = read_packet(port, buffer)
    assert %{"id" => 2, "result" => nil} = response

    Port.command(port, packet(%{"jsonrpc" => "2.0", "method" => "exit"}))
  end

  defp packet(payload) do
    body = Jason.encode!(payload)
    ["Content-Length: ", Integer.to_string(byte_size(body)), "\r\n\r\n", body]
  end

  defp read_packet(port, buffer) do
    case parse_packet(buffer) do
      {:ok, packet, rest} ->
        {Jason.decode!(packet), rest}

      :more ->
        receive do
          {^port, {:data, data}} -> read_packet(port, buffer <> data)
          {^port, {:exit_status, status}} -> flunk("stdio server exited with status #{status}")
        after
          10_000 -> flunk("timed out waiting for stdio response")
        end
    end
  end

  defp parse_packet(buffer) do
    case :binary.match(buffer, "\r\n\r\n") do
      :nomatch ->
        :more

      {header_end, 4} ->
        header = binary_part(buffer, 0, header_end)
        body_start = header_end + 4
        [_, length] = Regex.run(~r/Content-Length:\s*(\d+)/i, header)
        length = String.to_integer(length)

        if byte_size(buffer) >= body_start + length do
          body = binary_part(buffer, body_start, length)
          rest = binary_part(buffer, body_start + length, byte_size(buffer) - body_start - length)
          {:ok, body, rest}
        else
          :more
        end
    end
  end
end
