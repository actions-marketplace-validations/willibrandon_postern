Postern for Helix is a `languages.toml` entry and a set of queries. The entry names the [Postern](https://github.com/willibrandon/postern) language server and the [tree-sitter grammar](https://github.com/willibrandon/tree-sitter-postgresql-conf) for `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and `pg_ident.conf`; the queries give Helix highlighting and text objects for settings, rules, maps and options.

Append `languages.toml` to `~/.config/helix/languages.toml`, put the `queries/postgresql-conf` directory under `~/.config/helix/runtime/queries/`, then run `hx --grammar fetch` and `hx --grammar build`. From a checkout, `scripts/install-local.sh` does all of that. The server must be on your `PATH` as `postern`. The install script fetches the binary for your platform from the latest release and puts it in `~/.local/bin`, or where `--dir` says:

    curl -fsSL https://raw.githubusercontent.com/willibrandon/postern/main/scripts/install.sh | sh

Binaries are also on the [releases page](https://github.com/willibrandon/postern/releases).

The entry also claims `postgresql.base.conf`, which Patroni keeps the original file as, and a `.conf` file under a `conf.d` directory below a `postgresql` directory, which is how Debian lays out an `include_dir`. For another layout, add a `glob` to `file-types`.

`hx --health postgresql-conf` shows what Helix found.

## Settings

The server's options go in the `config` table of the language server entry in `languages.toml`, which Helix passes as initialization options:

```toml
[language-server.postern]
command = "postern"
config = { pg = 16, reportTrust = false }
```

| Option             | Default | Description                                                                                                                                                                                     |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pg`               | newest  | PostgreSQL major version, 13 to 18, for offline checks. A `# postern: pg=16` comment at the top of a file overrides it.                                                                         |
| `connectionString` | none    | `postgres://` URL of a server to check the open files against. Without it, `PGHOST` and the other libpq variables in the server's environment are used when set.                               |
| `reportTrust`      | `true`  | Hint on `pg_hba.conf` rules that use `trust` or `password` on a non-local address. Loopback and `samehost` are never reported, and the quick fix on a hint turns this off until the server restarts. |
