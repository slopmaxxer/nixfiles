# trough ActivityPub server at https://fedi.freifick.net (loopback 127.0.0.1:8790).
# Source: https://github.com/slopmaxxer/trough (flake input `trough`).
{ inputs, lib, pkgs, config, ... }: let
  cfg = config.services.trough;
  # Admin commands as the service user with the service's settings, e.g. `troughctl user list`.
  troughctl = pkgs.writeShellScriptBin "troughctl" ''
    exec /run/wrappers/bin/sudo -u trough ${pkgs.coreutils}/bin/env \
      TROUGH_HOST=${cfg.host} TROUGH_LISTEN=${cfg.listen} TROUGH_DATA=/var/lib/trough \
      ${lib.getExe cfg.package} "$@"
  '';
in {
  imports = [ ./caddy.nix inputs.trough.nixosModules.default ];

  services.trough = {
    enable = true;
    host = "fedi.freifick.net"; # permanent: embedded in federation IDs
    # Arch's /etc/trough.env only repeated host/listen/data, which the module sets.
  };
  environment.systemPackages = [ troughctl ];

  systemd.services.trough.serviceConfig = {
    # Secrets (TROUGH_DEEPSEEK_API_KEY), root-only and optional; copied, never in Nix.
    EnvironmentFile = [ "-/etc/trough-secrets.env" ];
    # Hardening of the Arch unit beyond the upstream module.
    ProtectClock = true;
    ProtectHostname = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" ];
    AmbientCapabilities = "";
  };

  users.users.trough.uid = 966;
  users.groups.trough.gid = 965;

  services.caddy.virtualHosts."fedi.freifick.net" = {
    # Access logs (client IPs) only for about a week, not in the system journal.
    logFormat = ''
      output file /var/log/caddy/fedi.freifick.net.log {
        roll_interval 24h
        roll_keep_for 168h
      }
    '';
    extraConfig = ''
      import security_headers
      # embedded posts may be framed by other sites (trough sends frame-ancestors *)
      @embed path_regexp ^/s/[^/]+/embed$
      header @embed -X-Frame-Options
      encode zstd gzip
      request_body {
        max_size 90MB
      }
      reverse_proxy ${cfg.listen}
    '';
  };
}
