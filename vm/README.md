# Always-on T3 Code server on a free VM

Firebase Studio and Codespaces suspend idle workspaces; nothing there survives you closing the
tab. For a server that stays up, use a real VM. Oracle Cloud's Always Free tier is the only
no-cost option without idle shutdown.

| Provider | Free shape | Idle kill | Notes |
| --- | --- | --- | --- |
| Oracle Cloud Always Free | A1 ARM, up to 4 OCPU / 24 GB / 200 GB | none | needs card for identity; A1 often "out of capacity", retry or try another AD |
| GCP Always Free | e2-micro, 1 GB RAM | none | too small for t3 + claude + codex comfortably |
| Hetzner CX22 | ~4 EUR/month | none | not free, painless |

Everything below works on any Ubuntu 22.04/24.04 VM, x86_64 or arm64.

## 1. Cloudflare named tunnel (stable URL, WebSocket-safe)

Cloudflare Zero Trust → Networks → Tunnels → Create tunnel → Cloudflared → copy the token.
Add a public hostname, e.g. `t3.example.com` → service `http://localhost:9271`.
No inbound ports are opened on the VM; `t3 serve` binds loopback only.

Alternative or addition: a Tailscale auth key (`TS_AUTHKEY`). Then pair with
`sudo -u t3 t3 pair --tailscale --base-dir /home/t3/.t3` and only your tailnet can reach it.

## 2. Create the VM with cloud-init

Copy `cloud-init.yaml`, fill `CF_TUNNEL_TOKEN` and `CF_TUNNEL_HOST`, paste as user data.

Oracle Cloud console: Compute → Instances → Create → Image **Ubuntu 24.04** (aarch64 for A1)
→ Shape **VM.Standard.A1.Flex** (e.g. 2 OCPU / 12 GB) → Advanced options → Management →
**Cloud-init script** → paste. Add your SSH key. Create.

Same file works as GCP "user-data" metadata, Hetzner "Cloud config", DigitalOcean "User data".

First boot takes ~3–5 min (apt, Node 22, `npm i -g t3` compiles node-pty). Progress:

```bash
ssh ubuntu@<vm-ip> sudo tail -f /var/log/t3-install.log
```

## 3. Pair

```bash
ssh ubuntu@<vm-ip> sudo t3-pair 15m
```

Paste the `https://t3.example.com/pair#token=...` URL into the T3 desktop/mobile app "Add
environment". Sessions live in `/home/t3/.t3`; they survive reboots, no re-pairing.

Then log the agents in once, as the service user:

```bash
ssh ubuntu@<vm-ip>
sudo -iu t3
claude                      # follow the login prompt
codex login --device-auth
```

Clone repos into `/home/t3/projects` and add them with `t3 project` or from the UI.

## Operating

```bash
sudo systemctl status t3 cloudflared
sudo journalctl -u t3 -f
sudo t3-pair 10m                                  # new pairing token
curl -fsSL https://raw.githubusercontent.com/Minoo7/t3code-idx/main/vm/install.sh | sudo bash   # upgrade t3, re-apply config
```

Re-running `install.sh` is idempotent; it reads `/etc/t3-vm.env` if you `set -a; . /etc/t3-vm.env`
first (cloud-init does this for you).

## More VMs

Paste the same cloud-init into each new instance with a different `CF_TUNNEL_HOST` (one
tunnel per VM, or one tunnel with several hostnames). With the OCI CLI:

```bash
oci compute instance launch --availability-domain <AD> --compartment-id <ocid> \
  --shape VM.Standard.A1.Flex --shape-config '{"ocpus":2,"memoryInGBs":12}' \
  --image-id <ubuntu-24.04-aarch64-image-ocid> --subnet-id <subnet-ocid> \
  --user-data-file cloud-init.yaml --ssh-authorized-keys-file ~/.ssh/id_ed25519.pub \
  --display-name t3-2
```
