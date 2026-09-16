defmodule Postern.RuntimeArgs do
  @moduledoc """
  Provides command-line arguments in Mix and Burrito environments.
  """

  if Code.ensure_loaded?(Burrito.Util.Args) do
    alias Burrito.Util.Args, as: BurritoArgs

    @doc "Returns arguments passed to the Burrito executable."
    @spec argv() :: [String.t()]
    def argv, do: BurritoArgs.argv()
  else
    @doc "Returns the VM command-line arguments."
    @spec argv() :: [String.t()]
    def argv, do: System.argv()
  end
end
