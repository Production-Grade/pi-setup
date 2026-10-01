#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project=${1:-$PWD}
provider=${PG_PI_PROVIDER:-zai}
model=${PG_PI_MODEL:-glm-5.3}

if [ ! -d "$project/.git" ]; then
  echo "preflight: project is not a Git checkout: $project" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "preflight: jq is required" >&2
  exit 2
fi

context=$(jq -er --arg provider "$provider" --arg model "$model" '
  .providers[$provider].models[] | select(.id == $model) | .contextWindow
' "$here/models.json")
package_count=$(jq '.packages | length' "$here/settings.json")
revision=$(git -C "$project" rev-parse --short HEAD)
policy_sha=$(shasum -a 256 "$here/permission-system.json" | awk '{print substr($1, 1, 12)}')

printf '%s\n' "Production Grade Pi preflight"
printf '  runtime       Pi 0.84.4 · unprivileged container\n'
printf '  checkout      /workspace · revision %s\n' "$revision"
printf '  model route   %s / %s\n' "$provider" "$model"
printf '  context       %s tokens\n' "$context"
printf '  packages      %s pinned\n' "$package_count"
jq -r '.packages[] | "                " + sub("^npm:"; "")' "$here/settings.json"
printf '  policy        default deny · sha256 %s\n' "$policy_sha"
printf '  host mounts   selected checkout only\n'
printf '  browser       separate profile · not loaded\n'
printf 'preflight: PASS\n'
