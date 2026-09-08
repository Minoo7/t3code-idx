#!/usr/bin/env bash
# Install or update the T3 Code CLI plus agent CLIs into the persistent home prefix.
set -euo pipefail

PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
mkdir -p "$PREFIX"
export PATH="$PREFIX/bin:$PATH"

want="${T3_VERSION:-latest}"
have="$(t3 --version 2>/dev/null | sed -E 's/^t3 v//' || true)"
latest="$(npm view "t3@${want}" version 2>/dev/null || true)"

if [ -z "$have" ] || { [ -n "$latest" ] && [ "$have" != "$latest" ]; }; then
  echo "[t3-idx] installing t3@${want} (have: ${have:-none}, target: ${latest:-?})"
  npm install -g "t3@${want}"
else
  echo "[t3-idx] t3 v${have} already current"
fi

# Agent providers T3 Code drives. Skip with T3_SKIP_AGENTS=1.
if [ "${T3_SKIP_AGENTS:-0}" != "1" ]; then
  command -v claude >/dev/null 2>&1 || npm install -g @anthropic-ai/claude-code
  command -v codex  >/dev/null 2>&1 || npm install -g @openai/codex
fi

mkdir -p "${T3CODE_HOME:-$HOME/.t3}" "$HOME/projects"
echo "[t3-idx] done. Once the preview is up, run: bash .idx/pair.sh"
