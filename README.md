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

## What runs on every workspace open

`dev.nix` `onStart` runs three things: `install.sh` (installs/updates `t3`, `claude`, `codex`
into `~/.npm-global`), `serve.sh --daemon` (supervised `t3 serve` on fixed port 9271, log in
`~/.t3/serve.log`), and `tunnel.sh --daemon` (Cloudflare tunnel, log in `~/.t3/tunnel.log`).
There is no web preview: the Cloud Workstations public-port proxy returns 503 on WebSocket
upgrades, so the T3 desktop/mobile apps cannot connect through it. Browser access through the
Google-authenticated port URL still works.

## Pairing

```bash
bash .idx/pair.sh          # default ttl 1h; pass e.g. 15m or 24h
```

Prints a token plus one URL per reachable route:

- **Cloudflare tunnel URL**: paste into the desktop/mobile app "Add environment".
- **Cloud Workstations port URL**: open in a browser signed into the same Google account.

## Stable tunnel (recommended)

Without configuration `tunnel.sh` starts a *quick* tunnel: random `*.trycloudflare.com` host,
new every restart, so every restart means re-pairing. For a stable host:

1. Cloudflare dashboard → Zero Trust → Networks → Tunnels → Create tunnel → Cloudflared.
   Copy the token. Public hostname: pick e.g. `t3.example.com` → service `http://localhost:9271`.
2. In the workspace terminal:
   ```bash
   printf '%s' 'TOKEN' > ~/.t3/cf-tunnel-token && chmod 600 ~/.t3/cf-tunnel-token
   printf '%s' 't3.example.com' > ~/.t3/cf-tunnel-host
   bash .idx/tunnel.sh --daemon
   ```
3. Pair once with `https://t3.example.com/pair#token=...`. Sessions persist in `~/.t3`, so
   later workspace restarts reconnect without re-pairing.

Agents: run `claude` and `codex login --device-auth` once in the terminal. Clone repos into
`~/projects`; add them with `t3 project` or from the UI.

## Limits worth knowing

- Free plan: 3 workspaces per account (10 with Google Developer Program, 30 with Premium).
- `/home` is 10 GiB and persists; `/tmp` and the Nix store are 100 GiB and rebuilt.
- Workspaces sleep when idle; running agents die, `~/.t3` state survives. Reopening the
  workspace restarts server and tunnel. Nothing on the free tier stays up unattended.
