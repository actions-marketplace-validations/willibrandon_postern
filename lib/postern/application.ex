defmodule Postern.Application do
  @moduledoc "Starts the Postern LSP application and its stdio transport."

  use Application

  @impl true
  def start(_type, _args) do
    Logger.configure(level: :warning)
    env = if Code.ensure_loaded?(Mix), do: Mix.env(), else: :prod

    args = runtime_args()

    case Enum.find_index(args, &(&1 == "check")) do
      nil -> :ok
      index -> System.halt(Postern.CLI.run(Enum.drop(args, index)))
    end

    children =
      if env == :test do
        []
      else
        [
          {GenLSP.Buffer, communication: {GenLSP.Communication.Stdio, []}, name: GenLSP.Buffer},
          {Postern.Server, [buffer: GenLSP.Buffer]}
        ]
      end

    opts = [strategy: :one_for_one, name: Postern.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp runtime_args do
    Postern.RuntimeArgs.argv()
  end
end
