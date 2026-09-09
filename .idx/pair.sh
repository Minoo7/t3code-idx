#!/usr/bin/env bash
# Mint a fresh pairing token and print pairing URLs.
# Usage: bash .idx/pair.sh [ttl]   (ttl examples: 15m, 1h, 24h; default 1h)
set -euo pipefail
export PATH="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin:$PATH"

T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
port="$(cat "$T3_HOME/idx-port" 2>/dev/null || echo 9271)"
ttl="${1:-1h}"

out="$(t3 pair --ttl "$ttl" --label "firebase-studio-$(printf %s "${WEB_HOST:-idx}" | cut -d. -f1)" 2>&1)"
token="$(printf '%s\n' "$out" | sed -nE 's/^Token: *([A-Z0-9]+).*/\1/p' | head -n1)"

if [ -z "$token" ]; then
  printf '%s\n' "$out"
  echo "[t3-idx] could not parse a token; is t3 serve running? (bash .idx/serve.sh --daemon)" >&2
  exit 1
fi

echo "Token (ttl $ttl): $token"
if [ -s "$T3_HOME/tunnel-url" ]; then
  echo "Desktop/mobile app (Cloudflare tunnel, WebSocket OK):"
  echo "  $(cat "$T3_HOME/tunnel-url")/pair#token=$token"
fi
if [ -n "${WEB_HOST:-}" ]; then
  echo "Browser signed into this Google account (Cloud Workstations port URL):"
  echo "  https://${port}-${WEB_HOST}/pair#token=$token"
fi
