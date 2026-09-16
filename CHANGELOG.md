# Changelog

## [Unreleased]

- Settings whose changes need a server restart are no longer reported as problems. That is a
  property of the setting, not a fault in the file, so it now appears in the hover instead. A
  live server that has not yet applied a changed value still gets its pending-restart note.

## [0.1.1] - 2026-09-16

- Fixed a crash when a live server was reachable: the oracle returned its snapshot wrapped in
  `{:ok, map}` while diagnostics, completion, inlay hints and code actions expected the map, so
  every request on an open file failed once a connection succeeded. Inlay hints and code actions
  now apply to `postgresql.conf` only.

## [0.1.0] - 2026-09-16

- Language server for `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and
  `pg_ident.conf`, speaking LSP over stdio.
- Offline diagnostics from catalogs of `pg_settings` for PostgreSQL 13 through 18: unknown
  settings with a suggestion, bad values and units, settings removed between versions, duplicate
  keys, and `pg_hba.conf` rules that an earlier rule shadows.
- Live diagnostics from `pg_file_settings`, `pg_hba_file_rules` and `pg_ident_file_mappings` when a
  connection string is configured, so the editor shows the server's own parse errors before a
  reload.
- Hover, completion, inlay hints and code actions.
- `postern check` for scripts and CI, plus `--help` and `--version`.
- Logs go to stderr without colour, so they can never corrupt the protocol stream.
- Single-file binaries for Linux, macOS and Windows, and a VS Code extension.
