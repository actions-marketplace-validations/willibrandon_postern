#!/usr/bin/env bash
set -euo pipefail

package_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}
install_root="$config_root/fresh/bundles/packages/postern"

mkdir -p "$install_root"
rsync -a --delete --delete-excluded --exclude 'node_modules/' "$package_root/" "$install_root/"

echo "Installed the Postern bundle from $package_root into $install_root"
