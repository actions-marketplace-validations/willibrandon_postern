Postern for Emacs is `postgresql-conf-ts-mode`, a major mode for `postgresql.conf`, `postgresql.auto.conf`, `pg_hba.conf` and `pg_ident.conf` in Emacs 29.1 or newer. Highlighting, Imenu and defun navigation come from the [tree-sitter grammar](https://github.com/willibrandon/tree-sitter-postgresql-conf); Eglot runs the [Postern](https://github.com/willibrandon/postern) language server, `postern` on your `PATH` when it is there. Without one, `M-x postgresql-conf-ts-mode-install-server` fetches the binary for your platform from the latest release into `~/.emacs.d/postern/`, checks it against the checksums the release carries, and Eglot uses it from then on; with a prefix argument it asks for a version.

The mode also owns `postgresql.base.conf`, which Patroni keeps the original file as, a `.conf` file under a `conf.d` directory below a `postgresql` directory, which is how Debian lays out an `include_dir`, and any file whose first line is a `# postern:` comment.

Install from a checkout:

```elisp
(add-to-list 'load-path "~/src/postern/editors/emacs")
(require 'postgresql-conf-ts-mode)
```

or with `package-vc-install`:

```elisp
(package-vc-install '(postgresql-conf-ts-mode :url "https://github.com/willibrandon/postern" :lisp-dir "editors/emacs"))
```

The parser is a library Emacs compiles from the grammar. `M-x postgresql-conf-ts-mode-install-grammar` builds it into `~/.emacs.d/tree-sitter/`, which needs Git and a C compiler; Emacs 31 offers to do that the first time the mode opens a file. Until then the mode only knows the comment syntax.

Start the server with `M-x eglot`, or add `postgresql-conf-ts-mode-hook` to `eglot-ensure`. Code actions, the quick fixes among them, are `M-x eglot-code-actions`.

## Settings

The server's options are `postgresql-conf-ts-mode-server-options`, a plist Eglot passes as initialization options, with `:json-false` for false:

```elisp
(setq postgresql-conf-ts-mode-server-options '(:pg 16 :reportTrust :json-false))
```

| Option             | Default | Description                                                                                                                                                                                     |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pg`               | newest  | PostgreSQL major version, 13 to 18, for offline checks. A `# postern: pg=16` comment at the top of a file overrides it.                                                                         |
| `connectionString` | none    | `postgres://` URL of a server to check the open files against. Without it, `PGHOST` and the other libpq variables in the server's environment are used when set.                               |
| `reportTrust`      | `true`  | Hint on `pg_hba.conf` rules that use `trust` or `password` on a non-local address. Loopback and `samehost` are never reported, and the quick fix on a hint turns this off until the server restarts. |

Tests run in batch and need `POSTERN_PARSER_DIR` pointing at a directory with the compiled grammar library:

    emacs -Q --batch -L . -l tests/postgresql-conf-ts-mode-test.el -f ert-run-tests-batch-and-exit
