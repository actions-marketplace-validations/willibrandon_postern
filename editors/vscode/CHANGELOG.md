# Changelog

## [0.1.2] - 2026-09-16

- Settings that need a restart to change are no longer listed as problems; the hover says so
  instead.

## [0.1.1] - 2026-09-16

- Fixed the bundled server crashing on every request once it could reach a PostgreSQL server.

## [0.1.0] - 2026-09-16

- Language support for `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and `pg_ident.conf`.
- Bundled Postern language server for Linux, macOS and Windows, with `postern.path` for another
  binary.
- Settings for the target PostgreSQL version and for a live connection string.
- Highlighting only in VS Code for the Web.
