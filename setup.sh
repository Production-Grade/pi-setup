#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image_name="${PG_PI_IMAGE:-productiongrade-pi:0.84.4}"
install_dir="${PG_PI_BIN_DIR:-$HOME/.local/bin}"

command -v docker >/dev/null 2>&1 || {
  printf '%s\n' "Docker is required before running setup." >&2
  exit 1
}

docker build \
  -f "$repo_dir/preset/Dockerfile.pi" \
  -t "$image_name" \
  "$repo_dir/preset"

docker volume create productiongrade-pi-state >/dev/null
mkdir -p "$install_dir"
install -m 0755 "$repo_dir/bin/pi" "$install_dir/pi"

printf '%s\n' "Installed the Pi launcher at $install_dir/pi"
if [[ ":$PATH:" != *":$install_dir:"* ]]; then
  printf '%s\n' "Add $install_dir to PATH, then open a repository and run: pi"
else
  printf '%s\n' "Open a repository and run: pi"
fi
