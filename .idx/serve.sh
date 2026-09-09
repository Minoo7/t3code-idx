#!/usr/bin/env bash
# Run the T3 Code server headless on a fixed port. With --daemon, supervise it in the
# background (restart on exit) and return immediately; used from dev.nix onStart.
set -euo pipefail
export PATH="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin:$PATH"

PORT="${T3_PORT:-9271}"
T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
LOG="$T3_HOME/serve.log"
mkdir -p "$T3_HOME" "$HOME/projects"
echo "$PORT" > "$T3_HOME/idx-port"

# The service launcher context leaks into child shells on some hosts; never inherit it here.
unset T3_SERVICE_LAUNCHER_CONTEXT T3_BOOT_SERVICE_UNIT

run_once() {
  exec t3 serve --host 0.0.0.0 --port "$PORT" --auto-bootstrap-project-from-cwd "$HOME/projects"
}

if [ "${1:-}" != "--daemon" ]; then
  run_once
fi

if pgrep -f "t3 serve --host 0.0.0.0 --port $PORT" >/dev/null 2>&1; then
  echo "[t3-idx] t3 serve already running on :$PORT"
  exit 0
fi

nohup bash -c '
  while true; do
    t3 serve --host 0.0.0.0 --port "$0" --auto-bootstrap-project-from-cwd "$1"
    echo "[t3-idx] t3 serve exited ($?); restarting in 3s"
    sleep 3
  done
' "$PORT" "$HOME/projects" >>"$LOG" 2>&1 &
disown
echo "[t3-idx] t3 serve supervised on :$PORT (log: $LOG)"
