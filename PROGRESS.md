# Postern Progress Ledger

This file is the checked-in continuation record for the project. Update it at
the end of each numbered phase and before starting the next one.

## Phase status

| Phase | Status | Evidence / next action |
| --- | --- | --- |
| 0. Skeleton | Complete | Commit `ef3ecb7`; `Postern.Server`, `Postern.DocumentStore`, `Postern.FileKind`, JSON-RPC tests. |
| 1. Parsers | Complete | Three NimbleParsec-backed parser modules, fixture round trips, token spans, and exact parse-error diagnostics; committed after all gates passed. |
| 2. Catalogs / `postgresql.conf` diagnostics | Complete | Generated pg13–pg18 catalogs from `pg_settings`; added catalog loading, version selection, Jaro suggestions, type/range/enum/unit checks, duplicate hints, removed-setting warnings, and restart information. |
| 3. `pg_hba.conf` / `pg_ident.conf` diagnostics | In progress | Add CIDR, option, shadowing, and ident-map checks. |
| 4. Hover / completion | Not started | Add LSP requests and fixture-backed ExUnit tests. |
| 5. Live oracle | Not started | Read `postgrex` source before implementing supervision and queries. |
| 6. CLI / packaging | Not started | Add `postern check`, JSON output, Burrito targets, and CI. |
| 7. Editor smoke tests | Not started | Add Neovim and Helix scripts; document Zed and VS Code. |

## Verified foundation

- Elixir 1.18.3 / OTP 27.3.4.1 and Mix 1.18.3 are installed.
- Dependencies are locked in `mix.lock`; dependency source was inspected before
  using GenLSP and NimbleParsec APIs.
- The project uses `gen_lsp 0.9.x`; the ElixirLS extension was removed from
  the remote extension set because it vendors the same `GenLSP.*` module names
  and conflicts with this project while compiling dependencies. The
  Expert remains available for syntax, hover documentation, completion and
  diagnostics.
- PostgreSQL fixtures have been copied from a PostgreSQL installation into
  `test/fixtures/`.
- `priv/catalog/pg13.json` through `priv/catalog/pg18.json` are generated
  artifacts from the required `pg_settings` query.
- `mix compile --warnings-as-errors` passes after the current edits.
- ExUnit is configured for normal parallel scheduling; no global `max_cases: 1`
  workaround is used. LSP tests use unique supervised-process names.
- Current gates pass: 36 parallel ExUnit tests, `mix compile
  --warnings-as-errors`, `mix credo --strict`, and `mix format --check-formatted`.

## Current work item

Begin Phase 3 by adding offline `pg_hba.conf` and `pg_ident.conf` diagnostics
for addresses, method options, rule reachability, and ident-map references.

The ElixirLS extension is intentionally not used for this project because its
vendored `GenLSP.*` modules conflict with Postern's `gen_lsp` dependency.

## Required evidence before completion

The final audit must map every item in `docs/original-brief.md` to source,
tests, generated catalogs, fixtures, command output, or CI configuration. A
green test command alone is not sufficient evidence for the definition of done.
