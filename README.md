# Postern

A Language Server Protocol (LSP) server for PostgreSQL configuration files — `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf`, and `pg_ident.conf`. Nothing like it exists yet.

Postern provides offline diagnostics, hover, completion, and an optional live connection to a running PostgreSQL instance for exact `pg_file_settings` diagnostics.

## Stack

* Elixir 1.18+ / OTP 27+
* [`gen_lsp`](deps/gen_lsp/usage-rules.md) — stdio transport
* [`nimble_parsec`](https://hex.pm/packages/nimble_parsec) — grammars
* [`postgrex`](https://hex.pm/packages/postgrex) — optional live oracle
* [`jason`](https://hex.pm/packages/jason) — JSON
* [`burrito`](https://hex.pm/packages/burrito) — single-binary releases (prod only)
* ExUnit, Credo, `mix format`

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

Phases (see `AGENTS.md`):

0. Skeleton — `GenLSP` server with in-memory document store.
1. Parsers — three `NimbleParsec` grammars with spans.
2. Catalogs & offline `postgresql.conf` diagnostics.
3. Offline `pg_hba.conf` / `pg_ident.conf` diagnostics.
4. Hover & completion.
5. Live oracle via `Postgrex`.
6. CLI & Burrito packaging.
7. Editor smoke tests.

Ground rules:

* Read `deps/*/lib` source before using a function — never guess.
* `priv/catalog/pg13.json … pg18.json` are generated from `pg_settings` via Docker on `5432`+`5413..5418`. Keep generator as `mix postern.catalog`.
* Every diagnostic/hover/completion gets an ExUnit test with a fixture under `test/fixtures/`.
* `mix test` green, `mix credo --strict` clean, `mix format --check-formatted`, `mix compile --warnings-as-errors`.

## License

MIT
