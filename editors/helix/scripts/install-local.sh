#!/usr/bin/env bash
set -euo pipefail

package_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}/helix

mkdir -p "$config_root/runtime/queries"
ln -sfn "$package_root/queries/postgresql-conf" "$config_root/runtime/queries/postgresql-conf"

if [ -f "$config_root/languages.toml" ]; then
  if grep -q 'name = "postgresql-conf"' "$config_root/languages.toml"; then
    echo "languages.toml already has postgresql-conf"
  else
    printf '\n' >> "$config_root/languages.toml"
    cat "$package_root/languages.toml" >> "$config_root/languages.toml"
    echo "Appended the language to $config_root/languages.toml"
  fi
else
  cp "$package_root/languages.toml" "$config_root/languages.toml"
  echo "Wrote $config_root/languages.toml"
fi

# Helix fetches and builds every grammar in its list, and an unrelated one
# failing must not hide ours, so the result is checked directly.
hx --grammar fetch || true
hx --grammar build || true
test -f "$config_root/runtime/grammars/postgresql-conf.so" && echo "Built the postgresql-conf grammar" || {
  echo "The postgresql-conf grammar did not build" >&2
  exit 1
}
