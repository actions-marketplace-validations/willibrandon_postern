defmodule Postern.LiveFeatures do
  @moduledoc """
  Inlay hints and code actions backed by a live PostgreSQL snapshot.
  """

  alias GenLSP.Enumerations.CodeActionKind
  alias GenLSP.Structures.CodeAction
  alias GenLSP.Structures.Command
  alias GenLSP.Structures.InlayHint
  alias GenLSP.Structures.Position
  alias Postern.Parser.PostgresqlConf

  @doc "Returns effective-value and pending-restart inlay hints."
  @spec inlay_hints(String.t(), map() | {:error, atom()} | nil) :: [InlayHint.t()]
  def inlay_hints(_text, nil), do: []
  def inlay_hints(_text, {:error, _reason}), do: []

  def inlay_hints(text, %{settings: settings}) do
    {:ok, entries} = PostgresqlConf.parse(text)
    assignments = Map.new(Enum.filter(entries, &(&1.type == :assignment)), &{&1.name, &1})

    Enum.flat_map(settings, fn setting ->
      case Map.get(assignments, setting["name"]) do
        nil -> []
        entry -> effective_hint(entry, setting)
      end
    end)
  end

  @doc "Returns live PostgreSQL code actions when a snapshot is available."
  @spec code_actions(String.t(), map() | {:error, atom()} | nil) :: [CodeAction.t()]
  def code_actions(_uri, nil), do: []
  def code_actions(_uri, {:error, _reason}), do: []

  def code_actions(uri, %{settings: _settings}) do
    [
      action("Apply with ALTER SYSTEM SET", "postern.applyAlterSystem", uri),
      action("Run pg_reload_conf()", "postern.reloadConfig", uri),
      action("Show effective value", "postern.showEffectiveValue", uri)
    ]
  end

  defp effective_hint(entry, setting) do
    effective = setting["setting"]
    pending_restart = setting["pending_restart"] in [true, "t", "true", "on", 1, "1"]

    cond do
      pending_restart -> [hint(entry, " pending restart")]
      is_binary(effective) and effective != entry.value -> [hint(entry, " = #{effective}")]
      true -> []
    end
  end

  defp hint(entry, label) do
    %InlayHint{
      position: %Position{
        line: entry.value_span.line - 1,
        character: entry.value_span.end_col - 1
      },
      label: label,
      padding_left: true
    }
  end

  @doc "The commands the live code actions carry."
  def commands,
    do: ["postern.applyAlterSystem", "postern.reloadConfig", "postern.showEffectiveValue"]

  defp action(title, command, uri) do
    %CodeAction{
      title: title,
      kind: CodeActionKind.quick_fix(),
      command: %Command{title: title, command: command, arguments: [uri]}
    }
  end
end
