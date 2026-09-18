Postern for Fresh is a bundle for [Fresh](https://github.com/sinelaw/fresh) 0.4.10 or newer. It highlights `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and `pg_ident.conf` and starts the [Postern](https://github.com/willibrandon/postern) language server for them, which adds diagnostics, hover, completion, inlay hints and code actions.

Install it with `Package: Install from URL` using https://github.com/willibrandon/postern#editors/fresh. The server is not bundled. The install script fetches the binary for your platform from the latest release and puts it in `~/.local/bin`, `curl -fsSL https://raw.githubusercontent.com/willibrandon/postern/main/scripts/install.sh | sh`, or download one from the [releases page](https://github.com/willibrandon/postern/releases); put it on your `PATH` as `postern`, or name its location in `config.json`:

```json
{ "lsp": { "postgresql-conf": { "command": "/path/to/postern" } } }
```

## Settings

`pg` and `connectionString` go under the server's `initialization_options` in `config.json`, and `reportTrust` is a toggle in Fresh Settings under Plugin Settings, postern:

```json
{ "lsp": { "postgresql-conf": { "command": "postern", "initialization_options": { "pg": 16 } } } }
```

| Option             | Default | Description                                                                                                                                                                                     |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pg`               | newest  | PostgreSQL major version, 13 to 18, for offline checks. A `# postern: pg=16` comment at the top of a file overrides it.                                                                         |
| `connectionString` | none    | `postgres://` URL of a server to check the open files against. Without it, `PGHOST` and the other libpq variables in the server's environment are used when set.                               |
| `reportTrust`      | `true`  | Hint on `pg_hba.conf` rules that use `trust` or `password` on a non-local address. Loopback and `samehost` are never reported, and the quick fix on a hint turns this off until the server restarts. |

A package manifest can only claim files by extension, and `.conf` is not ours, so the bundle's plugin claims the file names when it loads, with `postgresql.base.conf`, which Patroni keeps the original file as, and `**/postgresql/**/conf.d/*.conf`, which is how Debian lays out an `include_dir`, then reloads the grammar registry so files that were already open, including one named on the command line, are picked up too. That is a per-session setting; `config.json` is never modified, and names or globs you list under `languages.postgresql-conf.filenames` are kept.

Development requires Node 24 or newer and Fresh on the `PATH`.

    npm ci
    npm run validate
    scripts/install-local.sh

The last command copies the package into `~/.config/fresh/bundles/packages/postern`, where Fresh picks it up on the next start.
