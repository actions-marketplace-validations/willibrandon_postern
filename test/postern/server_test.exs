defmodule Postern.ServerTest do
  use ExUnit.Case, async: true

  import GenLSP.Test

  setup do
    id = System.unique_integer([:positive])

    server =
      server(Postern.Server,
        test_mode: true,
        buffer_id: :"buffer_#{id}",
        assigns_id: :"assigns_#{id}",
        task_supervisor_id: :"task_supervisor_#{id}",
        lsp_id: :"lsp_#{id}"
      )

    client = client(server)

    on_exit(fn ->
      :gen_tcp.close(client.socket)
    end)

    %{server: server, client: client}
  end

  describe "initialize" do
    test "replies with server capabilities", %{server: _server, client: client} do
      id = 1

      request(client, %{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "initialize",
        "params" => %{
          "processId" => nil,
          "rootUri" => nil,
          "capabilities" => %{},
          "initializationOptions" => %{}
        }
      })

      assert_result(^id, %{
        "capabilities" => %{
          "textDocumentSync" => %{
            "openClose" => true,
            "change" => 1,
            "save" => %{"includeText" => true}
          }
        },
        "serverInfo" => %{"name" => "postern", "version" => _}
      })
    end

    test "stores initializationOptions and rootUri", %{server: server, client: client} do
      id = 2

      request(client, %{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "initialize",
        "params" => %{
          "processId" => nil,
          "rootUri" => "file:///workspace",
          "capabilities" => %{},
          "initializationOptions" => %{"pg" => 16}
        }
      })

      assert_result(^id, _result)

      # Give the server a moment to process the assign
      Process.sleep(50)
      assigns = server_assigns(server)
      assert assigns[:root_uri] == "file:///workspace"
      assert assigns[:initialization_options] == %{"pg" => 16}
    end
  end

  describe "shutdown / exit" do
    test "shutdown sets exit_code to 0", %{server: server, client: client} do
      # initialize first (required by LSP spec)
      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 10,
        "method" => "initialize",
        "params" => %{"processId" => nil, "rootUri" => nil, "capabilities" => %{}}
      })

      assert_result(10, _)

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "initialized",
        "params" => %{}
      })

      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 11,
        "method" => "shutdown"
      })

      assert_result(11, nil)
      Process.sleep(50)
      assigns = server_assigns(server)
      assert assigns[:exit_code] == 0
    end

    test "exit does not crash when test_mode true", %{server: server, client: client} do
      notify(client, %{"jsonrpc" => "2.0", "method" => "exit"})
      Process.sleep(50)
      assert alive?(server)
    end
  end

  describe "textDocument/didOpen, didChange, didClose" do
    setup %{server: _server, client: client} do
      # Ensure initialized
      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 100,
        "method" => "initialize",
        "params" => %{"processId" => nil, "rootUri" => nil, "capabilities" => %{}}
      })

      assert_result(100, _)

      :ok
    end

    test "stores document on didOpen", %{server: server, client: client} do
      uri = "file:///tmp/postgresql.conf"

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "ini",
            "version" => 1,
            "text" => "shared_buffers = 128MB\n"
          }
        }
      })

      Process.sleep(50)
      docs = server_assigns(server)[:documents]
      assert docs[uri].text == "shared_buffers = 128MB\n"
      assert docs[uri].version == 1
      assert docs[uri].kind == :postgresql_conf
      assert docs[uri].uri == uri
    end

    test "detects file kind for pg_hba.conf", %{server: server, client: client} do
      uri = "file:///etc/pg_hba.conf"

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "conf",
            "version" => 1,
            "text" => "local all all trust\n"
          }
        }
      })

      Process.sleep(50)
      docs = server_assigns(server)[:documents]
      assert docs[uri].kind == :pg_hba_conf
    end

    test "updates document on didChange (full sync)", %{server: server, client: client} do
      uri = "file:///tmp/postgresql.conf"

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "ini",
            "version" => 1,
            "text" => "shared_buffers = 128MB\n"
          }
        }
      })

      Process.sleep(50)

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didChange",
        "params" => %{
          "textDocument" => %{"uri" => uri, "version" => 2},
          "contentChanges" => [%{"text" => "shared_buffers = 256MB\n"}]
        }
      })

      Process.sleep(50)
      docs = server_assigns(server)[:documents]
      assert docs[uri].text == "shared_buffers = 256MB\n"
      assert docs[uri].version == 2
    end

    test "removes document on didClose", %{server: server, client: client} do
      uri = "file:///tmp/pg_ident.conf"

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "conf",
            "version" => 1,
            "text" => "mymap user1 pguser1\n"
          }
        }
      })

      Process.sleep(50)
      assert Map.has_key?(server_assigns(server)[:documents], uri)

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didClose",
        "params" => %{"textDocument" => %{"uri" => uri}}
      })

      Process.sleep(50)
      refute Map.has_key?(server_assigns(server)[:documents], uri)
    end

    test "later didOpen overrides earlier", %{server: server, client: client} do
      uri = "file:///tmp/postgresql.conf"

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "ini",
            "version" => 1,
            "text" => "a = 1\n"
          }
        }
      })

      Process.sleep(50)

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => uri,
            "languageId" => "ini",
            "version" => 2,
            "text" => "b = 2\n"
          }
        }
      })

      Process.sleep(50)
      docs = server_assigns(server)[:documents]
      assert docs[uri].text == "b = 2\n"
      assert docs[uri].version == 2
    end
  end

  describe "JSON-RPC pipe behavior" do
    test "initialize over TCP (simulates pipe) returns capabilities", %{
      server: _server,
      client: client
    } do
      id = 999

      request(client, %{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "initialize",
        "params" => %{
          "processId" => nil,
          "rootUri" => nil,
          "capabilities" => %{}
        }
      })

      assert_result(^id, result)
      assert result["serverInfo"]["name"] == "postern"
      assert get_in(result, ["capabilities", "textDocumentSync", "openClose"]) == true
    end
  end

  describe "hover and completion" do
    setup %{client: client} do
      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 300,
        "method" => "initialize",
        "params" => %{"processId" => nil, "rootUri" => nil, "capabilities" => %{}}
      })

      assert_result(300, _)

      notify(client, %{
        "jsonrpc" => "2.0",
        "method" => "textDocument/didOpen",
        "params" => %{
          "textDocument" => %{
            "uri" => "file:///tmp/postgresql.conf",
            "languageId" => "conf",
            "version" => 1,
            "text" => "shared_buffers = 128MB\n"
          }
        }
      })

      Process.sleep(50)
      :ok
    end

    test "answers textDocument/hover", %{client: client} do
      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 301,
        "method" => "textDocument/hover",
        "params" => %{
          "textDocument" => %{"uri" => "file:///tmp/postgresql.conf"},
          "position" => %{"line" => 0, "character" => 7}
        }
      })

      assert_result(301, %{"contents" => %{"kind" => "markdown", "value" => value}})
      assert value =~ "shared_buffers"
    end

    test "answers textDocument/completion", %{client: client} do
      request(client, %{
        "jsonrpc" => "2.0",
        "id" => 302,
        "method" => "textDocument/completion",
        "params" => %{
          "textDocument" => %{"uri" => "file:///tmp/postgresql.conf"},
          "position" => %{"line" => 0, "character" => 7}
        }
      })

      assert_result(302, %{"isIncomplete" => false, "items" => items})
      assert Enum.any?(items, &(&1["label"] == "shared_buffers"))
    end
  end

  defp server_assigns(server) do
    GenLSP.Assigns.get(server.assigns)
  end
end
