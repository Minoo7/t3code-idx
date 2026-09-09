#!/usr/bin/env bash
# Provision an always-on T3 Code server on a fresh Ubuntu 22.04/24.04 VM (x86_64 or arm64).
# Idempotent; safe to re-run. Called from cloud-init.yaml, or run by hand as root:
#   curl -fsSL https://raw.githubusercontent.com/Minoo7/t3code-idx/main/vm/install.sh | sudo bash
#
# Env (all optional):
#   T3_USER=t3                 service user
#   T3_PORT=9271               loopback port t3 serve binds
#   T3_VERSION=latest          npm version of t3
#   T3_SKIP_AGENTS=0           1 = skip installing claude/codex CLIs
#   CF_TUNNEL_TOKEN=...        Cloudflare named-tunnel token; installs cloudflared as a service
#   CF_TUNNEL_HOST=t3.example  public hostname (only used for the pairing hint)
#   TS_AUTHKEY=...             Tailscale auth key; joins the tailnet and serves t3 over HTTPS
set -euo pipefail

T3_USER="${T3_USER:-t3}"
T3_PORT="${T3_PORT:-9271}"
T3_VERSION="${T3_VERSION:-latest}"
T3_HOME_DIR="/home/$T3_USER"
T3_DATA="$T3_HOME_DIR/.t3"
NPM_PREFIX="$T3_HOME_DIR/.npm-global"

log() { echo "[t3-vm] $*"; }
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q curl ca-certificates gnupg git build-essential python3 ripgrep jq unzip

# Node 22 from NodeSource (t3 requires ^22.16 || >=24.10).
if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
  log "installing Node 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -q nodejs
fi

if ! id "$T3_USER" >/dev/null 2>&1; then
  log "creating user $T3_USER"
  useradd --create-home --shell /bin/bash "$T3_USER"
fi
install -d -o "$T3_USER" -g "$T3_USER" -m 700 "$T3_DATA"
install -d -o "$T3_USER" -g "$T3_USER" "$NPM_PREFIX" "$T3_HOME_DIR/projects"

# Persist npm prefix + PATH for interactive shells of the service user.
if ! grep -q 'npm-global' "$T3_HOME_DIR/.profile" 2>/dev/null; then
  cat >>"$T3_HOME_DIR/.profile" <<EOF
export NPM_CONFIG_PREFIX="$NPM_PREFIX"
export PATH="$NPM_PREFIX/bin:\$PATH"
export T3CODE_HOME="$T3_DATA"
EOF
  chown "$T3_USER:$T3_USER" "$T3_HOME_DIR/.profile"
fi

as_user() { sudo -u "$T3_USER" -H env NPM_CONFIG_PREFIX="$NPM_PREFIX" PATH="$NPM_PREFIX/bin:$PATH" T3CODE_HOME="$T3_DATA" "$@"; }

have="$(as_user t3 --version 2>/dev/null | sed -E 's/^t3 v//' || true)"
want="$(npm view "t3@${T3_VERSION}" version 2>/dev/null || true)"
if [ -z "$have" ] || { [ -n "$want" ] && [ "$have" != "$want" ]; }; then
  log "installing t3@${T3_VERSION} (have: ${have:-none})"
  as_user npm install -g "t3@${T3_VERSION}"
else
  log "t3 v$have current"
fi
if [ "${T3_SKIP_AGENTS:-0}" != "1" ]; then
  as_user sh -c 'command -v claude >/dev/null 2>&1' || as_user npm install -g @anthropic-ai/claude-code
  as_user sh -c 'command -v codex  >/dev/null 2>&1' || as_user npm install -g @openai/codex
fi

# systemd unit: loopback only; tunnels (cloudflared / tailscale) provide the reachable edge.
cat >/etc/systemd/system/t3.service <<EOF
[Unit]
Description=T3 Code server (headless)
After=network-online.target
Wants=network-online.target

[Service]
User=$T3_USER
Group=$T3_USER
WorkingDirectory=$T3_HOME_DIR/projects
Environment=NPM_CONFIG_PREFIX=$NPM_PREFIX
Environment=PATH=$NPM_PREFIX/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=T3CODE_HOME=$T3_DATA
Environment=T3CODE_NO_BROWSER=1
Environment=T3CODE_TELEMETRY_ENABLED=0
ExecStart=$NPM_PREFIX/bin/t3 serve --host 127.0.0.1 --port $T3_PORT --auto-bootstrap-project-from-cwd $T3_HOME_DIR/projects
Restart=always
RestartSec=3
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now t3.service
log "t3.service enabled on 127.0.0.1:$T3_PORT"

# Cloudflare named tunnel → stable https hostname, WebSocket OK.
if [ -n "${CF_TUNNEL_TOKEN:-}" ]; then
  if ! command -v cloudflared >/dev/null 2>&1; then
    log "installing cloudflared"
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" >/etc/apt/sources.list.d/cloudflared.list
    apt-get update -q && apt-get install -y -q cloudflared
  fi
  # `service install` writes the token to /etc/systemd/system/cloudflared.service; re-running
  # with the same token is a no-op, so uninstall first to allow token rotation.
  if [ -n "${CF_TUNNEL_HOST:-}" ]; then
    echo "https://$CF_TUNNEL_HOST" >"$T3_DATA/tunnel-url"
    chown "$T3_USER:$T3_USER" "$T3_DATA/tunnel-url"
  fi
  cloudflared service uninstall >/dev/null 2>&1 || true
  if cloudflared service install "$CF_TUNNEL_TOKEN"; then
    systemctl enable --now cloudflared >/dev/null 2>&1 || true
    log "cloudflared service installed; tunnel public hostname must point at http://localhost:$T3_PORT"
  else
    log "WARNING: cloudflared service install failed (bad token?). Fix /etc/t3-vm.env and re-run." >&2
  fi
fi

# Tailscale: private alternative; t3 pair --tailscale publishes over Tailscale Serve.
if [ -n "${TS_AUTHKEY:-}" ]; then
  command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh
  tailscale up --authkey "$TS_AUTHKEY" --ssh
  log "tailscale up; pair with: sudo -u $T3_USER t3 pair --tailscale --base-dir $T3_DATA"
fi

# Pairing helper for humans.
cat >/usr/local/bin/t3-pair <<EOF
#!/usr/bin/env bash
# Mint a pairing token and print the URL(s). Usage: t3-pair [ttl]
set -euo pipefail
ttl="\${1:-1h}"
out="\$(sudo -u $T3_USER -H env NPM_CONFIG_PREFIX=$NPM_PREFIX PATH=$NPM_PREFIX/bin:\$PATH T3CODE_HOME=$T3_DATA t3 pair --ttl "\$ttl" --label "\$(hostname)" 2>&1)"
token="\$(printf '%s\n' "\$out" | sed -nE 's/^Token: *([A-Z0-9]+).*/\1/p' | head -n1)"
[ -n "\$token" ] || { printf '%s\n' "\$out"; exit 1; }
echo "Token (ttl \$ttl): \$token"
[ -s "$T3_DATA/tunnel-url" ] && echo "  \$(cat "$T3_DATA/tunnel-url")/pair#token=\$token"
echo "  http://127.0.0.1:$T3_PORT/pair#token=\$token   (via ssh -L $T3_PORT:127.0.0.1:$T3_PORT)"
EOF
chmod +x /usr/local/bin/t3-pair

log "done. Next: t3-pair 15m ; then as $T3_USER run 'claude' and 'codex login --device-auth'."
