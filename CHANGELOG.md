# Changelog

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
- `postern check` for scripts and CI.
- Single-file binaries for Linux, macOS and Windows, and a VS Code extension.
