# Dev instance of our Hydra fork at https://hydra.freifick.net (hydra-server on 127.0.0.1:3000).
# Source: https://github.com/slopmaxxer/hydra (flake input `hydra`). Its package is used with the
# fork's own lock (no `follows`), so the store paths match the builds of the
# hydra.kyouma.net jobset slopinger-hydra:main and come from cache.kyouma.net (common/nix.nix).
# Admin: `hydractl hydra-create-user …`; slop's admin password is ~/.secrets/hydra/admin-password.
{ inputs, lib, pkgs, config, ... }: let
  cfg = config.services.hydra-dev;
  # Admin commands as the hydra user with the service's environment, e.g. `hydractl hydra-create-user`.
  hydractl = pkgs.writeShellScriptBin "hydractl" ''
    cmd=$1; shift
    exec /run/wrappers/bin/sudo -u hydra ${pkgs.coreutils}/bin/env \
      HYDRA_DBI='${cfg.dbi}' HYDRA_CONFIG=/var/lib/hydra/hydra.conf HYDRA_DATA=/var/lib/hydra \
      ${cfg.package}/bin/"$cmd" "$@"
  '';
in {
  imports = [ ./caddy.nix inputs.hydra.nixosModules.hydra ];

  services.hydra-dev = {
    enable = true;
    package = inputs.hydra.packages.${pkgs.stdenv.hostPlatform.system}.hydra;
    hydraURL = "https://hydra.freifick.net";
    listenHost = "127.0.0.1";
    port = 3000;
    liveUpdates.enable = true;
    notificationSender = "hydra@freifick.net"; # no SMTP: emails are never sent
    # Builds run on this host through nix-daemon; fetch what caches already have.
    useSubstitutes = true;
    minimumDiskFree = 20;
    minimumDiskFreeEvaluator = 10;
  };
  # The queue runner builds through `nix-store --serve` against the daemon, which only builds
  # input-addressed derivations for trusted users. The module's `extra-trusted-users` line has no
  # effect next to common/nix.nix's `trusted-users` on Lix 2.95, so list it here (hydra-www stays
  # untrusted on purpose).
  nix.settings.trusted-users = [ "hydra-queue-runner" ];
  environment.systemPackages = [ hydractl ];

  services.caddy.virtualHosts."hydra.freifick.net" = {
    logFormat = null;
    extraConfig = ''
      import security_headers
      @live path /_live/events /_live/log/*
      handle @live {
        reverse_proxy 127.0.0.1:${toString cfg.liveUpdates.port} {
          flush_interval -1
        }
      }
      handle {
        encode zstd gzip
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';
  };
}
