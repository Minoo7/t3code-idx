#!/usr/bin/env bash
# Retrofit an EXISTING Firebase Studio workspace with the T3 Code template.
# Usage (inside the workspace terminal, from the workspace root):
#   curl -fsSL https://raw.githubusercontent.com/Minoo7/t3code-idx/main/bootstrap.sh | bash
set -euo pipefail

REPO_URL="${T3_IDX_REPO:-https://github.com/Minoo7/t3code-idx}"
ROOT="${1:-$PWD}"

if [ ! -d "$ROOT/.idx" ] && [ -z "${1:-}" ]; then
  # Not at a workspace root; fall back to the only folder under /home/user.
  cand="$(find "$HOME" -maxdepth 2 -name .idx -type d 2>/dev/null | head -n1 || true)"
  [ -n "$cand" ] && ROOT="$(dirname "$cand")"
fi
cd "$ROOT"
echo "[t3-idx] workspace root: $ROOT"

tmp="$(mktemp -d)"
git clone --depth 1 --quiet "$REPO_URL" "$tmp/t3idx"

if [ -d .idx ]; then
  bak=".idx.bak.$(date +%Y%m%d%H%M%S)"
  mv .idx "$bak"
  echo "[t3-idx] old .idx moved to $bak"
fi
cp -r "$tmp/t3idx/.idx" .idx
chmod +x .idx/*.sh
rm -rf "$tmp"

# Best effort: install now so the first rebuild boot is faster. Node may not exist yet.
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  T3_SKIP_AGENTS="${T3_SKIP_AGENTS:-0}" bash .idx/install.sh || echo "[t3-idx] pre-install skipped; onStart will retry"
else
  echo "[t3-idx] node not present yet; install runs after rebuild"
fi

cat <<'EOF'

[t3-idx] .idx replaced. Now rebuild the environment:
  Command Palette (F1 / Cmd+Shift+P) -> "Firebase Studio: Rebuild Environment"
  (or: Firebase Studio panel -> Hard Restart)

After the workspace reloads, the "web" preview runs t3 serve. Then:
  bash .idx/pair.sh
EOF
