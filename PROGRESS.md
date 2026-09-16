# Postern Progress Ledger

This file is the checked-in continuation record for the project. Update it at
the end of each numbered phase and before starting the next one.

## Phase status

| Phase | Status | Evidence / next action |
| --- | --- | --- |
| 0. Skeleton | Complete | Commit `ef3ecb7`; `Postern.Server`, `Postern.DocumentStore`, `Postern.FileKind`, JSON-RPC tests. |
| 1. Parsers | Complete | Three NimbleParsec-backed parser modules, fixture round trips, token spans, and exact parse-error diagnostics; committed after all gates passed. |
| 2. Catalogs / `postgresql.conf` diagnostics | In progress | Generate catalogs from PostgreSQL 13–18 containers; do not hand-author setting metadata. |
| 3. `pg_hba.conf` / `pg_ident.conf` diagnostics | Not started | Add CIDR, option, shadowing, and ident-map checks after Phase 2. |
| 4. Hover / completion | Not started | Add LSP requests and fixture-backed ExUnit tests. |
| 5. Live oracle | Not started | Read `postgrex` source before implementing supervision and queries. |
| 6. CLI / packaging | Not started | Add `postern check`, JSON output, Burrito targets, and CI. |
| 7. Editor smoke tests | Not started | Add Neovim and Helix scripts; document Zed and VS Code. |

## Verified foundation

- Elixir 1.18.3 / OTP 27.3.4.1 and Mix 1.18.3 are installed.
- Dependencies are locked in `mix.lock`; dependency source was inspected before
  using GenLSP and NimbleParsec APIs.
- The project pins `gen_lsp 0.9.x` because ElixirLS 0.31.x vendors the
  compatible `schematic/0` protocol; `gen_lsp 0.11.x` caused a
  `MessageType.schematic/0` crash through module redefinition.
- PostgreSQL fixtures have been copied from a PostgreSQL installation into
  `test/fixtures/`.
- Fixtures copied from the container are under `test/fixtures/`.
- `mix compile --warnings-as-errors` passes after the current edits.
- ExUnit is configured for normal parallel scheduling; no global `max_cases: 1`
  workaround is used. LSP tests use unique supervised-process names.
- Current gates pass: 29 parallel ExUnit tests, `mix compile
  --warnings-as-errors`, `mix credo --strict`, and `mix format --check-formatted`.

## Current work item

Begin Phase 2 by adding the catalog generator and producing
`priv/catalog/pg13.json` through `priv/catalog/pg18.json` from PostgreSQL
servers. Then add catalog loading and offline `postgresql.conf` diagnostics.

After the ElixirLS dependency fix, reload the VS Code window so the previously
crashed language-server process is replaced. The retained pre-fix crash log is
not evidence of a post-fix failure; a direct ElixirLS 0.31.1 launch now boots
without the `MessageType.schematic/0` exception.

## Required evidence before completion

The final audit must map every item in `docs/original-brief.md` to source,
tests, generated catalogs, fixtures, command output, or CI configuration. A
green test command alone is not sufficient evidence for the definition of done.
