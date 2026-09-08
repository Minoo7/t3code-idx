# T3 Code on Firebase Studio

Disposable Firebase Studio (formerly Project IDX) workspaces that run a headless
[T3 Code](https://github.com/pingdotgg/t3code) server. Every click on the button below creates a
fresh VM with `t3 serve` supervised as the workspace preview.

[<img src="https://cdn.firebasestudio.dev/btn/open_dark_32.svg" alt="Open in Firebase Studio">](https://studio.firebase.google.com/import?url=https://github.com/Minoo7/t3code-idx)


> **Firebase Studio stopped accepting new workspaces on June 22, 2026** and shuts down
> March 22, 2027. The import button above no longer works. Existing workspaces still run;
> retrofit one with the section below.

## Retrofit an existing workspace

Open the old workspace, open a terminal at the workspace root, paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Minoo7/t3code-idx/main/bootstrap.sh | bash
```

It backs up the old `.idx/`, drops in this template's `.idx/`, and pre-installs `t3` if Node
is already present. Then Command Palette → **Firebase Studio: Rebuild Environment**. After the
reload the `web` preview runs `t3 serve`; run `bash .idx/pair.sh` for the pairing link.

## What happens on create

1. `.idx/dev.nix` provisions Node 22, Bun, git, gh, ripgrep and a C toolchain (node-pty fallback).
2. `.idx/install.sh` installs `t3`, `@anthropic-ai/claude-code` and `@openai/codex` into
   `~/.npm-global`. Home persists across workspace restarts; the Nix profile does not.
3. The `web` preview runs `.idx/serve.sh`, which starts `t3 serve --host 0.0.0.0 --port $PORT`
   with `~/projects` as the bootstrap project directory.

## First use

1. Wait for the preview to come up (Firebase Studio panel > Previews, or the Backend ports list).
2. In a workspace terminal run:
   ```bash
   bash .idx/pair.sh          # default ttl 1h; pass e.g. 15m or 24h
   ```
3. Open the printed pairing URL in a browser signed into the same Google account.
   The T3 Code web client is served by the server itself and pairs with the token.
4. Log agents in from the terminal: `claude` (follow the login prompt) and `codex login --device-auth`.
5. Clone repos into `~/projects` and add them with `t3 project` or from the UI.

## Reaching the server from outside the browser

The forwarded port URL is gated by your Google cookie by default. For the T3 Code
desktop/mobile apps or anything without that cookie, either:

- Firebase Studio panel > Backend ports > click the lock next to the port to make it public.
  The pairing token still gates access, so mint short TTLs.
- Or run `t3 connect link --headless` once to use the T3 Connect relay instead of exposing the port.

## Environment knobs

| Variable | Default | Purpose |
| --- | --- | --- |
| `T3_VERSION` | `latest` | Pin the `t3` npm version installed at boot |
| `T3_SKIP_AGENTS` | `0` | Set `1` to skip installing the claude/codex CLIs |
| `T3CODE_HOME` | `/home/user/.t3` | Server state (SQLite, auth, worktrees) |

Set them in `.idx/dev.nix` under `env`.

## Limits worth knowing

- Free plan: 3 workspaces per account (10 with Google Developer Program, 30 with Premium).
- `/home` is 10 GiB and persists; `/tmp` and the Nix store are 100 GiB and rebuilt.
- Workspaces sleep when idle. The preview restarts on next open and `~/.t3` state survives.
