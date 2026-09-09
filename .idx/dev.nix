# Firebase Studio (ex Project IDX) workspace: headless T3 Code server.
# Docs: https://firebase.google.com/docs/studio/devnix-reference
{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.nodejs_22
    pkgs.bun
    pkgs.git
    pkgs.gh
    pkgs.ripgrep
    pkgs.jq
    pkgs.cloudflared
    # node-gyp fallback for node-pty when no prebuilt binary matches
    pkgs.python3
    pkgs.gcc
    pkgs.gnumake
  ];

  env = {
    # /home persists across restarts; the nix profile does not. Keep npm globals in home.
    NPM_CONFIG_PREFIX = "/home/user/.npm-global";
    PATH = [ "/home/user/.npm-global/bin" ];
    T3CODE_HOME = "/home/user/.t3";
    T3CODE_HOST = "0.0.0.0";
    T3CODE_NO_BROWSER = "1";
    T3CODE_TELEMETRY_ENABLED = "0";
    # Fixed port so tunnels and pairing URLs stay stable across restarts.
    T3_PORT = "9271";
  };

  idx = {
    extensions = [ ];

    workspace = {
      onCreate = {
        install-t3 = "bash .idx/install.sh";
      };
      onStart = {
        # Repair/upgrade on every boot; cheap when already current.
        ensure-t3 = "bash .idx/install.sh";
        # Supervised background server + Cloudflare tunnel (see tunnel.sh for named-tunnel setup).
        t3-serve = "bash .idx/serve.sh --daemon";
        t3-tunnel = "bash .idx/tunnel.sh --daemon";
      };
    };

    # No web preview: the Cloud Workstations proxy drops WebSocket upgrades on public ports,
    # and the preview iframe adds nothing over the tunnel URL.
    previews.enable = false;
  };
}
