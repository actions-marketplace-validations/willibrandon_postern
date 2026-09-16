#!/usr/bin/env bash
set -euo pipefail

# Opens a broken postgresql.conf in Neovim with the editors/nvim plugin on the
# runtime path and waits for a diagnostic from the server. Needs Neovim 0.11.

command -v nvim >/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bin="${POSTERN_BIN:-postern}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
printf 'port =\n' > "$tmp_dir/postgresql.conf"

export POSTERN_SMOKE_BIN="$bin"
nvim --headless -u NORC --cmd "set rtp^=$root/editors/nvim" \
  --cmd 'lua vim.lsp.config("postern", { cmd = { vim.env.POSTERN_SMOKE_BIN } })' \
  "+edit $tmp_dir/postgresql.conf" \
  +'lua assert(vim.bo.filetype == "postgresql-conf", "filetype was " .. vim.bo.filetype); vim.wait(10000, function() return #vim.diagnostic.get(0) > 0 end); assert(#vim.diagnostic.get(0) > 0, "Postern did not publish a diagnostic")' \
  +'qa!'
echo "neovim smoke: ok"
