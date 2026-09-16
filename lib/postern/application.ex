defmodule Postern.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    env = if Code.ensure_loaded?(Mix), do: Mix.env(), else: :prod

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
end
