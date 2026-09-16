defmodule Mix.Tasks.Postern.Catalog do
  @shortdoc "Generate PostgreSQL setting catalogs from PostgreSQL 13 through 18"

  @moduledoc """
  Generates `priv/catalog/pg13.json` through `priv/catalog/pg18.json` by
  querying Docker PostgreSQL servers on ports 5413 through 5418.

  Start the servers before running this task, for example:

      for v in 13 14 15 16 17 18; do
        docker run -d --name pg$v -e POSTGRES_HOST_AUTH_METHOD=trust -p 54$v:5432 postgres:$v
      done

  The task never invents setting metadata; all setting names, types, ranges,
  enum values and descriptions come from `pg_settings`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {options, remaining, _invalid} =
      OptionParser.parse(argv,
        strict: [
          hostname: :string,
          output_dir: :string
        ]
      )

    if remaining != [] do
      Mix.raise("unexpected arguments: #{Enum.join(remaining, " ")}")
    end

    Application.ensure_all_started(:postgrex)
    opts = Enum.filter(options, fn {key, _value} -> key in [:hostname, :output_dir] end)

    Enum.each(Postern.CatalogGenerator.default_ports(), fn {version, port} ->
      Mix.shell().info("Generating PostgreSQL #{version} catalog from port #{port}")
      Postern.CatalogGenerator.generate(version, port, opts)
    end)
  end
end
