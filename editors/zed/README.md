Postern for Zed is the `postgresql-conf` language extension. It gives `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and `pg_ident.conf` highlighting, an outline and text objects from the [tree-sitter grammar](https://github.com/willibrandon/tree-sitter-postgresql-conf), and runs the [Postern](https://github.com/willibrandon/postern) language server for them. The server is `postern` on your `PATH` when there is one; otherwise the extension downloads the binary for your platform from the latest release.

It also takes `postgresql.base.conf`, which Patroni keeps the original file as, and a file whose first line is a `# postern:` comment. Zed matches names rather than patterns, so a `.conf` file under a `conf.d` directory, Debian's `include_dir`, is a setting:

```json
{ "file_types": { "PostgreSQL Config": ["**/postgresql/**/conf.d/*.conf"] } }
```

Install it from a checkout with `zed: install dev extension` in the command palette, choosing this directory. Zed compiles the extension, which needs a Rust toolchain.

## Settings

The server's options go in Zed's settings under `lsp.postern.initialization_options`:

```json
{ "lsp": { "postern": { "initialization_options": { "pg": 16, "reportTrust": false } } } }
```

| Option             | Default | Description                                                                                                                                                                                     |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pg`               | newest  | PostgreSQL major version, 13 to 18, for offline checks. A `# postern: pg=16` comment at the top of a file overrides it.                                                                         |
| `connectionString` | none    | `postgres://` URL of a server to check the open files against. Without it, `PGHOST` and the other libpq variables in the server's environment are used when set.                               |
| `reportTrust`      | `true`  | Hint on `pg_hba.conf` rules that use `trust` or `password` on a non-local address. Loopback and `samehost` are never reported, and the quick fix on a hint turns this off until the server restarts. |
