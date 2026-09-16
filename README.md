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

## Editor Setup

Postern speaks LSP over stdio. Any client that supports `initialize`, `textDocument/didOpen|didChange|didClose` plus `hover`/`completion` works.

### Neovim (nvim-lspconfig)

```lua
local lspconfig = require("lspconfig")
local configs = require("lspconfig.configs")

if not configs.postern then
  configs.postern = {
    default_config = {
      cmd = { "postern" }, -- or "/path/to/burrito_out/postern_linux_x86_64"
      filetypes = { "conf" },
      root_dir = lspconfig.util.root_pattern("postgresql.conf", "pg_hba.conf", ".git"),
      settings = {},
      init_options = {
        -- optional: target version 13..18, defaults to newest catalog
        -- pg = 16,
        -- optional: live connection
        -- connectionString = "postgres://user:pass@localhost:5432/postgres"
      },
    },
  }
end

lspconfig.postern.setup({})
```

Or headless smoke test:

```sh
nvim --headless -c "lua require('lspconfig').postern.setup{cmd={'postern'}}" -c "e test/fixtures/postgresql.conf" -c "sleep 500m" -c "qa!"
```

### Helix

`languages.toml`:

```toml
[language-server.postern]
command = "postern"

[[language]]
name = "ini"
scope = "source.ini"
file-types = ["conf"]
roots = ["postgresql.conf", "pg_hba.conf"]
language-servers = ["postern"]

[[language]]
name = "pg_hba"
scope = "source.pg_hba"
file-types = ["conf"]
roots = ["pg_hba.conf"]
language-servers = ["postern"]
```

### Zed

Zed support is via the generic LSP client (owner will write the extension). Add to `settings.json`:

```json
{
  "lsp": {
    "postern": {
      "binary": { "path": "postern", "arguments": [] }
    }
  },
  "languages": {
    "PostgreSQL Config": {
      "language_servers": ["postern"]
    }
  }
}
```

### VS Code

The Expert extension can be used for Elixir syntax highlighting, hover
documentation, completion, diagnostics, navigation and formatting. It handles
`.ex` and `.exs` files; it is not the Postern LSP client for PostgreSQL
configuration files.

The future Postern VS Code client can independently launch `postern` over
stdio for `postgresql.conf`, `pg_hba.conf`, and `pg_ident.conf`.

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
