#!/usr/bin/env bash
# Mint a fresh pairing token and print the URL to open via the workspace's forwarded port.
# Usage: bash .idx/pair.sh [ttl]   (ttl examples: 15m, 1h, 24h; default 1h)
set -euo pipefail
export PATH="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin:$PATH"

port="$(cat "${T3CODE_HOME:-$HOME/.t3}/idx-port" 2>/dev/null || echo 9271)"
ttl="${1:-1h}"

out="$(t3 pair --ttl "$ttl" --label "firebase-studio-${WEB_HOST%%.*}" 2>&1)"
token="$(printf '%s\n' "$out" | sed -nE 's/^Token: *([A-Z0-9]+).*/\1/p' | head -n1)"

if [ -z "$token" ]; then
  printf '%s\n' "$out"
  echo "[t3-idx] could not parse a token; is the web preview running?" >&2
  exit 1
fi

# WEB_HOST is exported by Firebase Studio in web workspaces; fall back to manual assembly.
if [ -n "${WEB_HOST:-}" ]; then
  echo "Pairing URL (ttl $ttl):"
  echo "  https://${port}-${WEB_HOST}/pair#token=${token}"
else
  echo "Token (ttl $ttl): ${token}"
  echo "Firebase Studio panel > Backend ports > copy the URL for port ${port}, then append:"
  echo "  /pair#token=${token}"
fi
