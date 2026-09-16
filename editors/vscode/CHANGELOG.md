# Changelog

## [Unreleased]

- The trust quick fix command is registered by the language client, since the server now advertises
  it, and handled through the client's middleware. It still saves the setting.

## [0.1.6] - 2026-09-16

- Bundles server 0.1.6, which applies edits sent as ranges and handles the trust quick fix command
  itself. Neither changes anything for VS Code, which sends full text and runs the quick fix on its
  own.

## [0.1.5] - 2026-09-16

- Lines the server writes to stderr are logged at their own level. The wrapper's "Uninstalled older
  version" notice after an update is information, not an error.

## [0.1.4] - 2026-09-16

- Published as platform packages only. The universal package could be installed in the minutes
  before the platform package for a new version finished validating, leaving no server binary.

## [0.1.3] - 2026-09-16

- Trust on a non-local `pg_hba.conf` rule is a hint instead of a warning, and a new
  `postern.hba.reportTrust` setting, also reachable as a quick fix on the hint, turns it off.
- `all` no longer counts as shadowing `replication` rules.

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
