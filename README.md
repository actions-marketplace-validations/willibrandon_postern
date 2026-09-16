# Postern

A Language Server Protocol (LSP) server for PostgreSQL configuration files — `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf`, and `pg_ident.conf`.

Postern provides offline diagnostics, hover, completion, and an optional live connection to a running PostgreSQL instance for exact `pg_file_settings` diagnostics.

## Stack

* Elixir 1.18+ / OTP 27+
* gen_lsp for stdio LSP transport
* nimble_parsec for parsing
* postgrex for PostgreSQL connections
* jason for JSON
* burrito for releases
* ExUnit, Credo and `mix format`

## Installation

### Prerequisites

```sh
mise use -g erlang@27 elixir@1.18
# or asdf
mix local.hex --force && mix local.rebar --force
```

### Project

```sh
mix deps.get
mix compile --warnings-as-errors
mix test
mix credo --strict
mix format --check-formatted
```

### CLI

```sh
mix postern.catalog   # generate priv/catalog/pg13.json … pg18.json from Docker
postern check postgresql.conf pg_hba.conf
```

### Release (Burrito)

```sh
MIX_ENV=prod mix release
# binaries at burrito_out/postern_linux_x86_64 etc. (linux-x86_64, macos-arm64, windows-x86_64)
```

## LSP

Postern speaks LSP over stdio. Clients should launch the `postern` executable
and support `initialize`, document synchronization, diagnostics, hover and
completion as those capabilities become available.

## Configuration

Target Postgres version is resolved in order:

1. `initializationOptions.pg` (e.g. `16`)
2. `# postern: pg=16` comment at top of file
3. newest catalog (18)

## Development

```sh
mix test
mix credo --strict
mix format --check-formatted
mix compile --warnings-as-errors
```

Catalogs are generated from `pg_settings` with `mix postern.catalog`.
Diagnostics and LSP features have fixture-backed ExUnit tests.

## License

MIT
