defmodule Postern.Server do
  @moduledoc """
  Language Server Protocol server for PostgreSQL configuration files.

  Handles lifecycle requests (`initialize`, `shutdown`, `exit`) and
  the document synchronization notifications (`textDocument/didOpen`,
  `textDocument/didChange`, `textDocument/didClose`). Documents are
  kept in an in-memory store keyed by URI, with the file kind detected
  from the basename.

  The server is intentionally minimal in phase 0; diagnostics, hover
  and completion are added in later phases.
  """

  use GenLSP

  alias GenLSP.Enumerations.TextDocumentSyncKind
  alias GenLSP.Notifications.Exit, as: ExitNotification
  alias GenLSP.Notifications.Initialized
  alias GenLSP.Notifications.TextDocumentDidChange
  alias GenLSP.Notifications.TextDocumentDidClose
  alias GenLSP.Notifications.TextDocumentDidOpen
  alias GenLSP.Notifications.TextDocumentPublishDiagnostics
  alias GenLSP.Requests.Initialize
  alias GenLSP.Requests.Shutdown
  alias GenLSP.Structures.InitializeParams
  alias GenLSP.Structures.InitializeResult
  alias GenLSP.Structures.PublishDiagnosticsParams
  alias GenLSP.Structures.SaveOptions
  alias GenLSP.Structures.ServerCapabilities
  alias GenLSP.Structures.TextDocumentSyncOptions
  alias Postern.Diagnostics
  alias Postern.DocumentStore

  @server_name "postern"
  @server_version "0.1.0"

  # Public API

  @doc """
  Starts the language server.

  `args` is passed to `init/2`. `opts` is forwarded to `GenLSP.start_link/3`
  and should contain `:buffer`, `:assigns` and `:task_supervisor`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {args, gen_opts} = Keyword.split(opts, [:test_mode])

    gen_opts = Keyword.take(gen_opts, [:buffer, :name])

    GenLSP.start_link(__MODULE__, args, gen_opts)
  end

  # Callbacks

  @impl true
  def init(lsp, args) do
    test_mode = Keyword.get(args, :test_mode, false)

    {:ok,
     assign(lsp,
       documents: %{},
       exit_code: 1,
       test_mode: test_mode,
       initialization_options: nil,
       root_uri: nil
     )}
  end

  @impl true
  def handle_request(%Initialize{params: %InitializeParams{} = params}, lsp) do
    initialization_options = Map.get(params, :initialization_options)
    root_uri = Map.get(params, :root_uri)

    lsp =
      assign(lsp,
        initialization_options: initialization_options,
        root_uri: root_uri
      )

    result = %InitializeResult{
      capabilities: %ServerCapabilities{
        text_document_sync: %TextDocumentSyncOptions{
          open_close: true,
          change: TextDocumentSyncKind.full(),
          save: %SaveOptions{include_text: true}
        }
      },
      server_info: %{name: @server_name, version: @server_version}
    }

    {:reply, result, lsp}
  end

  def handle_request(%Shutdown{}, lsp) do
    {:reply, nil, assign(lsp, exit_code: 0)}
  end

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    {:noreply, lsp}
  end

  def handle_notification(%ExitNotification{}, lsp) do
    exit_code = Map.get(lsp.assigns, :exit_code, 0)
    test_mode = Map.get(lsp.assigns, :test_mode, false)
    test_env = Code.ensure_loaded?(Mix) and Mix.env() == :test

    unless test_mode or test_env do
      System.halt(exit_code)
    end

    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidOpen{params: params}, lsp) do
    doc = params.text_document
    lsp = DocumentStore.put(lsp, doc.uri, doc.text, doc.version, doc.language_id)
    publish_diagnostics(lsp, doc.uri, doc.text, doc.version)
    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidChange{params: params}, lsp) do
    uri = params.text_document.uri
    version = params.text_document.version
    changes = params.content_changes

    text =
      case List.last(changes) do
        %{text: t} -> t
        %{"text" => t} -> t
        _ -> ""
      end

    lsp = DocumentStore.update(lsp, uri, text, version)
    publish_diagnostics(lsp, uri, text, version)
    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidClose{params: params}, lsp) do
    uri = params.text_document.uri
    lsp = DocumentStore.delete(lsp, uri)

    GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
      params: %PublishDiagnosticsParams{uri: uri, diagnostics: []}
    })

    {:noreply, lsp}
  end

  # Gracefully ignore other notifications (didSave, etc.)
  def handle_notification(_notification, lsp) do
    {:noreply, lsp}
  end

  defp publish_diagnostics(lsp, uri, text, version) do
    diagnostics =
      Diagnostics.for_document(uri, text, Map.get(lsp.assigns, :initialization_options, %{}))

    GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
      params: %PublishDiagnosticsParams{uri: uri, version: version, diagnostics: diagnostics}
    })
  end
end
