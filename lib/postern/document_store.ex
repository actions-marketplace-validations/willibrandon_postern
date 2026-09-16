defmodule Postern.DocumentStore do
  @moduledoc """
  In-memory document store keyed by URI.

  Documents are stored as maps with keys:

  * `:uri` - document URI
  * `:language_id` - language identifier from the client
  * `:version` - document version
  * `:text` - full document text
  * `:kind` - file kind detected from the URI via `Postern.FileKind`

  The store lives inside `GenLSP.Assigns` under the key `:documents`.
  """

  alias Postern.FileKind

  @type uri :: String.t()
  @type document :: %{
          uri: uri(),
          language_id: String.t(),
          version: integer(),
          text: String.t(),
          kind: FileKind.t()
        }

  @doc """
  Returns all documents.
  """
  @spec all(GenLSP.LSP.t()) :: %{uri() => document()}
  def all(lsp) do
    Map.get(GenLSP.LSP.assigns(lsp), :documents, %{})
  end

  @doc """
  Fetches a document by URI.
  """
  @spec get(GenLSP.LSP.t(), uri()) :: document() | nil
  def get(lsp, uri) do
    lsp |> all() |> Map.get(uri)
  end

  @doc """
  Stores a document, overwriting any existing entry.
  """
  @spec put(GenLSP.LSP.t(), uri(), String.t(), integer(), String.t()) :: GenLSP.LSP.t()
  def put(lsp, uri, text, version, language_id \\ "") do
    kind = FileKind.detect(uri)

    doc = %{
      uri: uri,
      language_id: language_id,
      version: version,
      text: text,
      kind: kind
    }

    GenLSP.LSP.assign(lsp, fn assigns ->
      documents = Map.get(assigns, :documents, %{})
      [documents: Map.put(documents, uri, doc)]
    end)
  end

  @doc """
  Updates the text (and version) of an existing document. If the document
  does not exist, it is created.
  """
  @spec update(GenLSP.LSP.t(), uri(), String.t(), integer()) :: GenLSP.LSP.t()
  def update(lsp, uri, text, version) do
    case get(lsp, uri) do
      nil ->
        put(lsp, uri, text, version)

      existing ->
        kind = FileKind.detect(uri)

        doc = %{existing | text: text, version: version, kind: kind}

        GenLSP.LSP.assign(lsp, fn assigns ->
          documents = Map.get(assigns, :documents, %{})
          [documents: Map.put(documents, uri, doc)]
        end)
    end
  end

  @doc """
  Deletes a document from the store.
  """
  @spec delete(GenLSP.LSP.t(), uri()) :: GenLSP.LSP.t()
  def delete(lsp, uri) do
    GenLSP.LSP.assign(lsp, fn assigns ->
      documents = Map.get(assigns, :documents, %{})
      [documents: Map.delete(documents, uri)]
    end)
  end
end
