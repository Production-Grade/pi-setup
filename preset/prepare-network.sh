#!/usr/bin/env bash
set -euo pipefail

network_name="pg-pi-models"
proxy_name="pg-pi-model-proxy"
image_name="productiongrade-pi:0.84.4"
active_model="${1:---both}"
preset_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$active_model" in
  --ds4|--qwen|--both) ;;
  *)
    printf '%s\n' "usage: $0 [--ds4|--qwen|--both]" >&2
    exit 2
    ;;
esac

if ! docker network inspect "$network_name" >/dev/null 2>&1; then
  docker network create --internal "$network_name" >/dev/null
fi

if docker container inspect "$proxy_name" >/dev/null 2>&1; then
  docker stop "$proxy_name" >/dev/null
  docker rm "$proxy_name" >/dev/null
fi

docker run -d \
  --name "$proxy_name" \
  --network bridge \
  --add-host host.docker.internal:host-gateway \
  -v "$preset_dir/ollama-relay.py:/opt/pg/ollama-relay.py:ro" \
  --entrypoint sh \
  "$image_name" \
  -c 'socat TCP-LISTEN:8000,fork,reuseaddr TCP:host.docker.internal:8000 & exec python3 /opt/pg/ollama-relay.py --listen-port 11434 --upstream-host host.docker.internal --upstream-port 11434' \
  >/dev/null

docker network connect --alias model-proxy "$network_name" "$proxy_name"

if [[ "$active_model" == "--ds4" || "$active_model" == "--both" ]]; then
  docker run --rm --network "$network_name" --entrypoint python3 "$image_name" -c '
import json, urllib.request
with urllib.request.urlopen("http://model-proxy:8000/v1/models", timeout=10) as response:
    data = json.load(response)
assert any(model.get("id") == "deepseek-v4-flash" for model in data.get("data", []))
'
fi

if [[ "$active_model" == "--qwen" || "$active_model" == "--both" ]]; then
  docker run --rm --network "$network_name" --entrypoint python3 "$image_name" -c '
import json, urllib.request
with urllib.request.urlopen("http://model-proxy:11434/v1/models", timeout=10) as response:
    data = json.load(response)
assert any(model.get("id") == "pg-qwen3.8-27b-100k:latest" for model in data.get("data", []))
'
fi

if docker run --rm --network "$network_name" --entrypoint python3 "$image_name" -c '
import urllib.request
urllib.request.urlopen("https://example.com", timeout=5)
' >/dev/null 2>&1; then
  echo "internal network unexpectedly reached the public internet" >&2
  exit 1
fi

printf '%s\n' "model relay ready; ${active_model#--} route verified; public egress denied"
