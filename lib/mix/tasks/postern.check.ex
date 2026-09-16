defmodule Mix.Tasks.Postern.Check do
  @shortdoc "Check PostgreSQL configuration files"
  @moduledoc "Runs `postern check` from Mix for local development and tests."

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    System.halt(Postern.CLI.run(["check" | args]))
  end
end
