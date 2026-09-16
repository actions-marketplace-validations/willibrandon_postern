#!/usr/bin/env bash
set -euo pipefail

command -v hx >/dev/null
bin="${POSTERN_BIN:-postern}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/postgresql.conf" <<'EOF'
port =
EOF
mkdir -p "$tmp_dir/config/helix"
cat >"$tmp_dir/config/helix/languages.toml" <<EOF
[language-server.postern]
command = "$bin"

[[language]]
name = "postgresql"
scope = "source.postgresql"
file-types = [{ glob = "postgresql.conf" }]
language-servers = ["postern"]
EOF

log="$tmp_dir/helix.log"
timeout 8s script -qefc "env XDG_CONFIG_HOME='$tmp_dir/config' hx --log '$log' '$tmp_dir/postgresql.conf'" /dev/null >/dev/null 2>&1 || true

grep -q "textDocument/publishDiagnostics\|publishDiagnostics" "$log"
