# Postern: Original Project Brief

You are building "postern", a Language Server Protocol server for PostgreSQL
configuration files: postgresql.conf, postgresql.auto.conf, pg_hba.conf and
pg_ident.conf. Nothing like it exists yet. The owner has never written Elixir,
so the code must be idiomatic and readable, not clever.

## STACK

- Elixir 1.18+ / OTP 27+. Mix project created with `mix new postern --sup`.
- gen_lsp for the protocol (stdio transport), nimble_parsec for grammars,
  postgrex for the optional live connection, jason for JSON.
- ExUnit for tests. Credo and `mix format` clean. `mix compile --warnings-as-errors`.
- No Phoenix, no web UI. This is a stdio language server plus a small CLI
  (`postern check FILE...`) that prints diagnostics without an editor.

## GROUND RULES

1. Before using any function from a dependency, open its source under deps/
   (for example deps/gen_lsp/lib) and read the real signature. Do not guess.
2. Never type PostgreSQL setting names, types, ranges, enum values or
   descriptions from memory. Generate priv/catalog/pg13.json ... pg18.json by
   running `select name, vartype, unit, context, category, short_desc,
   extra_desc, min_val, max_val, enumvals, boot_val, reset_val from pg_settings`
   against the Docker containers on ports 5413..5418 and committing the JSON.
   Keep the generator as a mix task: `mix postern.catalog`.
3. Work in the numbered phases below. Finish a phase, run the full test suite,
   commit with a short prose message, then start the next. Do not skip ahead.
4. Every diagnostic, hover and completion gets an ExUnit test with a fixture
   file under test/fixtures. Prefer table-driven tests.
5. Write docs as you go: README.md with install and editor setup, and
   moduledocs on every public module.

## FILE FORMATS TO PARSE (use the PostgreSQL docs as the spec)

- postgresql.conf: `name = value` or `name value`, values may be quoted with
  '' escaping, units like 8MB or 30s or 2min, booleans in many spellings
  (on/off/true/false/yes/no/1/0 and prefixes), `#` comments, and the
  directives include, include_if_exists, include_dir (resolved relative to the
  file). Later entries override earlier ones. Track line and column
  spans for every token.
- pg_hba.conf: fields are type (local, host, hostssl, hostnossl, hostgssenc,
  hostnogssenc), database list, user list, address (CIDR, IP plus netmask,
  hostname, all, samehost, samenet), auth method (trust, reject,
  scram-sha-256, md5, password, gss, sspi, ident, peer, ldap, radius, cert,
  pam, bsd, oauth), and method options as name=value. PostgreSQL 16 added
  `include`, `include_if_exists` and `include_dir` here too, and regexes
  prefixed with `/` in database and user fields. Quoted tokens and
  comma-separated lists apply.
- pg_ident.conf: map-name system-username pg-username, with `/regex`
  system usernames and `\1` substitution.

## PHASES

### 0. Skeleton

gen_lsp server that answers initialize, shutdown, exit, and
textDocument/didOpen, didChange, didClose with an in-memory document
store keyed by URI. Detect file kind from the basename. A test that
speaks JSON-RPC over a pipe to the server and gets a capabilities reply.

### 1. Parsers

Three nimble_parsec grammars producing ASTs with spans. Round-trip tests
against the sample files that ship with a Postgres install (copy them from
the containers into test/fixtures). Parse errors become diagnostics with
the exact span.

### 2. Catalogs and offline diagnostics for postgresql.conf

Unknown setting (with a did-you-mean using Jaro distance over catalog names),
value does not fit vartype, out of min/max, not in enumvals, unit not allowed
for this vartype, duplicate key where a later line wins (hint severity),
setting removed or renamed between versions, context=postmaster settings
tagged with "requires restart". The target version comes from an
initializationOptions field, a `# postern: pg=16` comment, or defaults to the
newest catalog.

### 3. Offline diagnostics for pg_hba.conf and pg_ident.conf

Malformed CIDR or netmask, netmask on a hostname, options invalid for the
method (for example clientcert on a local line, ldap* options on a non-ldap
method), unreachable rule shadowed by an earlier rule that is a superset in
type, database, user and address (warning), trust or password on a non-local
line (warning), reject rules that shadow everything after them, ident map
referenced in pg_hba that does not exist in pg_ident.conf, and ident maps
never referenced.

### 4. Hover and completion

Hover on a setting shows short_desc, extra_desc, type, unit, default, range
or enum values, context and the version it first appeared in. Completion
offers setting names, enum values and boolean spellings in postgresql.conf,
and connection types, methods, method options and well-known address
keywords in pg_hba.conf.

### 5. Live oracle

If initializationOptions carries a connection string (or PGHOST/PGUSER style
env is present), open a Postgrex connection in a supervised process that
reconnects with backoff and never crashes the server. Read pg_settings,
pg_file_settings, pg_hba_file_rules and pg_ident_file_mappings. Map rows with
a non-null error to diagnostics on sourcefile/sourceline or
file_name/line_number when that file is the one open in the editor. Add inlay
hints showing the effective value when it differs from the file's value, and
mark pending_restart settings. Offer completion of real database and role
names. Code actions: "Apply with ALTER SYSTEM SET", "Run pg_reload_conf()",
"Show effective value". Everything in this phase must degrade to phase 2-4
behavior when the server is unreachable, with one informational diagnostic
saying so.

### 6. CLI and packaging

`postern check` exit code 1 on errors, plain and JSON output. Burrito release
producing single binaries for linux-x86_64, macos-arm64 and windows-x86_64. A
GitHub Actions workflow that runs tests against Postgres 13 through 18 service
containers.

### 7. Editor smoke tests

Scripts under test/editors that start Neovim headless with nvim-lspconfig,
and Helix with a languages.toml, open a fixture, and assert that a diagnostic
arrives. Document Zed and VS Code setup in the README; the owner will write
those clients himself.

## DEFINITION OF DONE

- `mix test` green, `mix credo --strict` clean, `mix format --check-formatted`.
- Opening the stock postgresql.conf from a Postgres 16 container yields zero
  errors; introducing `shared_buffers = 128QB` yields exactly one, on that
  line, with the same message the server itself reports via pg_file_settings.
- Opening a pg_hba.conf where line 3 is `host all all 0.0.0.0/0 trust` and
  line 4 is `host all all 10.0.0.0/8 scram-sha-256` warns on line 4 that it
  can never match.
