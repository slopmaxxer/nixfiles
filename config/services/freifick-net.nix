# https://freifick.net: static site + slopd (guestbook/visitor counter) behind /api/*.
# Source: https://github.com/slopmaxxer/slop-landing (flake input `slop-landing`;
# `nix flake update slop-landing` to deploy a new version).
{ config, pkgs, ... }: let
  slopd = config.freifick.slopd;
in {
  imports = [ ./caddy.nix ];

  # The guestbook is public and user-written: moderate it with
  # `slopctl list` / `slopctl hide <id>` / `slopctl delete <id>`.
  freifick.slopd.enable = true;
  # Numeric IDs of the Arch install, so migrated state keeps its owner.
  users.users.slopd.uid = 967;
  users.groups.slopd.gid = 967;

  services.caddy.virtualHosts = {
    "freifick.net" = {
      logFormat = "output stderr";
      extraConfig = ''
        import security_headers
        encode zstd gzip

        root * ${pkgs.slop-landing}

        # Guestbook + visitor counter API (slopd.service, loopback only)
        handle /api/* {
          request_body {
            max_size 8KB
          }
          reverse_proxy ${slopd.host}:${toString slopd.port}
        }

        handle {
          file_server
        }

        handle_errors 404 {
          rewrite * /404.html
          file_server
        }
      '';
    };

    # Old/alternate names: permanent redirect to the canonical site (308 keeps the method,
    # so API POSTs survive). slopd's ALLOWED_ORIGINS has to list every name.
    "www.freifick.net" = {
      serverAliases = [ "slop.kyouma.net" ];
      logFormat = null;
      extraConfig = ''
        import security_headers
        redir https://freifick.net{uri} 308
      '';
    };
  };
}
