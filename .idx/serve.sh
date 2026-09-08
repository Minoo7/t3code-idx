#!/usr/bin/env bash
# Preview command: run the T3 Code server headless on the port Firebase Studio assigns.
set -euo pipefail
export PATH="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin:$PATH"

PORT="${PORT:-9271}"
T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
mkdir -p "$T3_HOME" "$HOME/projects"
echo "$PORT" > "$T3_HOME/idx-port"

# The service launcher context leaks into child shells on some hosts; never inherit it here.
unset T3_SERVICE_LAUNCHER_CONTEXT T3_BOOT_SERVICE_UNIT

exec t3 serve \
  --host 0.0.0.0 \
  --port "$PORT" \
  --auto-bootstrap-project-from-cwd \
  "$HOME/projects"
