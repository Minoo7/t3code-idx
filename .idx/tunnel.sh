#!/usr/bin/env bash
# Expose the T3 server through Cloudflare so desktop/mobile clients can reach it over
# WebSocket (the Cloud Workstations public-port proxy drops WS upgrades).
#
#   Named tunnel (stable URL, survives restarts):
#     put the tunnel token in $T3CODE_HOME/cf-tunnel-token and the public hostname
#     (e.g. t3.example.com) in $T3CODE_HOME/cf-tunnel-host.
#   Quick tunnel (fallback): random *.trycloudflare.com URL, written to $T3CODE_HOME/tunnel-url.
#
# With --daemon, supervise in the background and return; used from dev.nix onStart.
set -euo pipefail

T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
PORT="$(cat "$T3_HOME/idx-port" 2>/dev/null || echo "${T3_PORT:-9271}")"
LOG="$T3_HOME/tunnel.log"
TOKEN_FILE="$T3_HOME/cf-tunnel-token"
HOST_FILE="$T3_HOME/cf-tunnel-host"
URL_FILE="$T3_HOME/tunnel-url"
mkdir -p "$T3_HOME"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[t3-idx] cloudflared missing; add pkgs.cloudflared to dev.nix and rebuild" >&2
  exit 1
fi

if pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
  echo "[t3-idx] cloudflared already running"
  [ -f "$URL_FILE" ] && echo "[t3-idx] url: $(cat "$URL_FILE")"
  exit 0
fi

if [ -s "$TOKEN_FILE" ]; then
  mode=named
  # Token via env, not argv, so it never shows in process listings.
  TUNNEL_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
  export TUNNEL_TOKEN
  cmd=(cloudflared tunnel --no-autoupdate run)
  [ -s "$HOST_FILE" ] && echo "https://$(tr -d '[:space:]' < "$HOST_FILE")" > "$URL_FILE"
else
  mode=quick
  cmd=(cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$PORT")
  rm -f "$URL_FILE"
fi

if [ "${1:-}" != "--daemon" ]; then
  exec "${cmd[@]}"
fi

nohup bash -c '
  while true; do
    "$@"
    echo "[t3-idx] cloudflared exited ($?); restarting in 5s"
    sleep 5
  done
' _ "${cmd[@]}" >>"$LOG" 2>&1 &
disown

if [ "$mode" = quick ]; then
  # Quick tunnels print their URL a few seconds after start.
  for _ in $(seq 1 30); do
    url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" | tail -n1 || true)"
    if [ -n "$url" ]; then echo "$url" > "$URL_FILE"; break; fi
    sleep 1
  done
fi
echo "[t3-idx] cloudflared ($mode) supervised (log: $LOG)"
[ -s "$URL_FILE" ] && echo "[t3-idx] url: $(cat "$URL_FILE")"
