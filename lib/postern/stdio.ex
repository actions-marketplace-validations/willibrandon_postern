defmodule Postern.Stdio do
  @moduledoc """
  The stdio transport, with one difference from GenLSP's own: when the editor
  closes the pipe, the VM halts at once.

  GenLSP calls `System.stop/0` on end of file, which is a graceful shutdown.
  Under Burrito the application never finishes starting (see
  `Postern.Application`), so that shutdown cannot complete, and an editor that
  closes the pipe in the same instant it sends `exit` can leave the process
  hanging until the editor kills it. An editor that closed the pipe is not
  coming back, so halting is the right answer.
  """

  @behaviour GenLSP.Communication.Adapter

  alias GenLSP.Communication.Stdio

  @impl true
  defdelegate init(args), to: Stdio

  @impl true
  defdelegate listen(state), to: Stdio

  @impl true
  defdelegate write(body, state), to: Stdio

  @impl true
  def read(state, buffer) do
    case Stdio.read(state, buffer) do
      :eof -> System.halt(0)
      other -> other
    end
  end
end
