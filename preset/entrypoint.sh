#!/bin/sh
set -eu

# Ollama rejects the internal relay hostname in the HTTP Host header. Keep Pi on
# the internal Docker network while presenting a localhost URL to Ollama.
socat TCP-LISTEN:11434,bind=127.0.0.1,fork,reuseaddr TCP:model-proxy:11434 &

exec pi --no-autoformat --no-autofix "$@"
