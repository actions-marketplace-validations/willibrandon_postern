# Postern Progress

This file records implementation progress.

## Phase status

| Phase | Status | Evidence / next action |
| --- | --- | --- |
| 0. Skeleton | Complete | Commit `ef3ecb7`; `Postern.Server`, `Postern.DocumentStore`, `Postern.FileKind`, JSON-RPC tests. |
| 1. Parsers | Complete | Three NimbleParsec-backed parser modules, fixture round trips, token spans, and exact parse-error diagnostics; committed after all gates passed. |
| 2. Catalogs / `postgresql.conf` diagnostics | Complete | Generated pg13–pg18 catalogs from `pg_settings`; added catalog loading, version selection, Jaro suggestions, type/range/enum/unit checks, duplicate hints, removed-setting warnings, and restart information. |
| 3. `pg_hba.conf` / `pg_ident.conf` diagnostics | Complete | Added CIDR/netmask validation, method-option checks, unsafe-method warnings, shadow/reject detection, and ident-map reference/unused-map diagnostics. |
| 4. Hover / completion | Complete | Added catalog-backed hover, PostgreSQL setting/value completion, HBA keyword completion, and LSP request tests. |
| 5. Live oracle | Complete | Added supervised reconnecting Postgrex snapshots, live file-setting diagnostics, inlay hints and code actions with offline fallback. |
| 6. CLI / packaging | Complete | Added `postern check`, plain/JSON output, Burrito targets and CI; all three target builds completed. |
| 7. Editor smoke tests | In progress | Added Neovim and Helix smoke scripts. |

## Checks

- Elixir 1.18.3 / OTP 27.3.4.1 and Mix 1.18.3 are installed.
- Dependencies are locked in `mix.lock`; dependency source was inspected before
  using GenLSP and NimbleParsec APIs.
- PostgreSQL fixtures have been copied from a PostgreSQL installation into
  `test/fixtures/`.
- `priv/catalog/pg13.json` through `priv/catalog/pg18.json` are generated
  artifacts from the required `pg_settings` query.
- `mix compile --warnings-as-errors` passes after the current edits.
- ExUnit is configured for normal parallel scheduling; no global `max_cases: 1`
  workaround is used. LSP tests use unique supervised-process names.
- Current gates pass: 55 parallel ExUnit tests, `mix compile
  --warnings-as-errors`, `mix credo --strict`, and `mix format --check-formatted`.

## Current work item

Run the editor smoke scripts in environments with the required clients.

The final check must cover the requirements in `docs/original-brief.md` with
source, tests, fixtures or command output.
