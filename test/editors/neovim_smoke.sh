#!/usr/bin/env bash
set -euo pipefail

command -v nvim >/dev/null
: "${NVIM_LSPCONFIG:?set NVIM_LSPCONFIG to the nvim-lspconfig directory}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
nvim --headless -u NONE --cmd "set rtp+=$NVIM_LSPCONFIG" +'lua assert(pcall(require, "lspconfig"), "nvim-lspconfig is required")' +qa

bin="${POSTERN_BIN:-postern}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cat >"$tmp_dir/postgresql.conf" <<'EOF'
port =
EOF

export POSTERN_SMOKE_BIN="$bin"
export POSTERN_SMOKE_FILE="$tmp_dir/postgresql.conf"

nvim --headless -u NONE --cmd "set rtp+=$NVIM_LSPCONFIG" \
  +'lua local lspconfig = require("lspconfig"); local configs = require("lspconfig.configs"); configs.postern = { default_config = { cmd = { vim.env.POSTERN_SMOKE_BIN }, filetypes = { "conf" }, single_file_support = true, root_dir = function() return vim.fs.dirname(vim.api.nvim_buf_get_name(0)) end } }; lspconfig.postern.setup({}); vim.cmd("edit " .. vim.env.POSTERN_SMOKE_FILE); vim.bo.filetype = "conf"; lspconfig.postern.manager:try_add_wrapper(0); vim.wait(5000, function() return #vim.diagnostic.get(0) > 0 end); assert(#vim.diagnostic.get(0) > 0, "Postern did not publish a diagnostic")' \
  +'qa!'
