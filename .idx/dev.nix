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
      };
    };

    previews = {
      enable = true;
      previews = {
        # The preview manager supervises the server and assigns $PORT.
        web = {
          command = [ "bash" ".idx/serve.sh" "$PORT" ];
          manager = "web";
        };
      };
    };
  };
}
