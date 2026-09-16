defmodule Postern.Server do
  @moduledoc """
  Language Server Protocol server for PostgreSQL configuration files.

  Handles lifecycle requests (`initialize`, `shutdown`, `exit`) and
  the document synchronization notifications (`textDocument/didOpen`,
  `textDocument/didChange`, `textDocument/didClose`). Documents are
  kept in an in-memory store keyed by URI, with the file kind detected
  from the basename.

  Diagnostics, hover and completion are provided by the server alongside
  document synchronization.
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
  alias GenLSP.Requests.TextDocumentCodeAction
  alias GenLSP.Requests.TextDocumentCompletion
  alias GenLSP.Requests.TextDocumentHover
  alias GenLSP.Requests.TextDocumentInlayHint
  alias GenLSP.Requests.WorkspaceExecuteCommand
  alias GenLSP.Structures.CompletionOptions
  alias GenLSP.Structures.InitializeParams
  alias GenLSP.Structures.InitializeResult
  alias GenLSP.Structures.PublishDiagnosticsParams
  alias GenLSP.Structures.SaveOptions
  alias GenLSP.Structures.ServerCapabilities
  alias GenLSP.Structures.TextDocumentSyncOptions
  alias Postern.Diagnostics
  alias Postern.DocumentStore
  alias Postern.Features
  alias Postern.FileKind
  alias Postern.LiveFeatures
  alias Postern.LiveOracle

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

    gen_opts =
      Keyword.take(gen_opts, [:buffer, :assigns, :task_supervisor, :name, :sync_notifications])

    GenLSP.start_link(__MODULE__, args, gen_opts)
  end

  # Callbacks

  @impl true
  def init(lsp, args) do
    test_mode = Keyword.get(args, :test_mode, false)
    {:ok, live_oracle} = LiveOracle.start_link(nil)

    {:ok,
     assign(lsp,
       documents: %{},
       exit_code: 1,
       test_mode: test_mode,
       initialization_options: nil,
       root_uri: nil,
       live_oracle: live_oracle
     )}
  end

  @impl true
  def handle_request(%Initialize{params: %InitializeParams{} = params}, lsp) do
    initialization_options = Map.get(params, :initialization_options)
    root_uri = Map.get(params, :root_uri)

    live_oracle =
      case LiveOracle.connection_options(initialization_options || %{}) do
        nil ->
          current_assigns(lsp).live_oracle

        options ->
          {:ok, oracle} = LiveOracle.start_link(options)
          oracle
      end

    lsp =
      assign(lsp,
        initialization_options: initialization_options,
        root_uri: root_uri,
        live_oracle: live_oracle
      )

    result = %InitializeResult{
      capabilities: %ServerCapabilities{
        text_document_sync: %TextDocumentSyncOptions{
          open_close: true,
          change: TextDocumentSyncKind.full(),
          save: %SaveOptions{include_text: true}
        },
        hover_provider: true,
        completion_provider: %CompletionOptions{trigger_characters: [".", "="]},
        inlay_hint_provider: true,
        code_action_provider: true
      },
      server_info: %{name: @server_name, version: @server_version}
    }

    {:reply, result, lsp}
  end

  def handle_request(%Shutdown{}, lsp) do
    {:reply, nil, assign(lsp, exit_code: 0)}
  end

  def handle_request(%TextDocumentHover{params: params}, lsp) do
    reply =
      case DocumentStore.get(lsp, params.text_document.uri) do
        %{text: text} ->
          Features.hover(
            params.text_document.uri,
            text,
            params.position,
            feature_options(lsp)
          )

        nil ->
          nil
      end

    {:reply, reply, lsp}
  end

  def handle_request(%TextDocumentCompletion{params: params}, lsp) do
    reply =
      case DocumentStore.get(lsp, params.text_document.uri) do
        %{text: text} ->
          Features.completion(
            params.text_document.uri,
            text,
            params.position,
            Map.get(current_assigns(lsp), :initialization_options, %{})
          )

        nil ->
          nil
      end

    {:reply, reply, lsp}
  end

  def handle_request(%TextDocumentInlayHint{params: params}, lsp) do
    reply =
      live_feature_result(lsp, params.text_document.uri, fn _uri, text, snapshot ->
        LiveFeatures.inlay_hints(text, snapshot)
      end)

    {:reply, reply, lsp}
  end

  def handle_request(%TextDocumentCodeAction{params: params}, lsp) do
    reply =
      live_feature_result(lsp, params.text_document.uri, fn uri, _text, snapshot ->
        LiveFeatures.code_actions(uri, snapshot)
      end)

    {:reply, reply, lsp}
  end

  def handle_request(%WorkspaceExecuteCommand{params: params}, lsp) do
    arguments = params.arguments || []
    uri = List.first(arguments)

    arguments =
      case DocumentStore.get(lsp, uri) do
        %{text: text} -> arguments ++ [text]
        nil -> arguments
      end

    reply = LiveOracle.execute(current_assigns(lsp).live_oracle, params.command, arguments)
    {:reply, reply, lsp}
  end

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    {:noreply, lsp}
  end

  def handle_notification(%ExitNotification{}, lsp) do
    exit_code = Map.get(current_assigns(lsp), :exit_code, 0)
    test_mode = Map.get(current_assigns(lsp), :test_mode, false)
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
    initialization_options = Map.get(current_assigns(lsp), :initialization_options, %{})

    base_options =
      if is_nil(initialization_options), do: %{}, else: Map.new(initialization_options)

    live_oracle = Map.get(current_assigns(lsp), :live_oracle)
    live_snapshot = if is_pid(live_oracle), do: LiveOracle.snapshot(live_oracle), else: nil

    options =
      base_options
      |> Map.merge(document_options(lsp))
      |> Map.put(:live_snapshot, live_snapshot)
      |> Map.put(:live_configured, LiveOracle.connection_options(base_options) != nil)

    diagnostics =
      Diagnostics.for_document(uri, text, options)

    GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
      params: %PublishDiagnosticsParams{uri: uri, version: version, diagnostics: diagnostics}
    })
  end

  defp live_feature_result(lsp, uri, callback) do
    case DocumentStore.get(lsp, uri) do
      %{text: text} ->
        snapshot = LiveOracle.snapshot(current_assigns(lsp).live_oracle)
        callback.(uri, text, snapshot)

      nil ->
        []
    end
  end

  defp feature_options(lsp) do
    initialization_options = Map.get(current_assigns(lsp), :initialization_options, %{})

    base_options =
      if is_nil(initialization_options), do: %{}, else: Map.new(initialization_options)

    Map.put(base_options, :live_snapshot, LiveOracle.snapshot(current_assigns(lsp).live_oracle))
  end

  defp current_assigns(lsp), do: GenLSP.LSP.assigns(lsp)

  defp document_options(lsp) do
    documents = DocumentStore.all(lsp)

    %{
      pg_hba_text: find_document_text(documents, :pg_hba_conf),
      pg_ident_text: find_document_text(documents, :pg_ident_conf)
    }
  end

  defp find_document_text(documents, kind) do
    Enum.find_value(documents, fn {uri, document} ->
      if FileKind.detect(uri) == kind, do: document.text
    end)
  end
end
