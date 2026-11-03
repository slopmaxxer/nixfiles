# slopbox temporary file host at https://slopbox.freifick.net (loopback 127.0.0.1:8791).
# Source: https://github.com/slopmaxxer/mayfly (flake input `mayfly`).
{ inputs, config, ... }: let
  cfg = config.services.mayfly;
in {
  imports = [ ./caddy.nix inputs.mayfly.nixosModules.default ];

  services.mayfly = {
    enable = true;
    url = "https://slopbox.freifick.net";
  };

  users.users.mayfly.uid = 963;
  users.groups.mayfly.gid = 963;

  services.caddy.virtualHosts = {
    "slopbox.freifick.net" = {
      logFormat = null;
      extraConfig = ''
        import security_headers
        request_body {
          max_size 202MiB
        }
        reverse_proxy 127.0.0.1:${toString cfg.port} {
          header_up X-Real-IP {remote_host}
        }
      '';
    };
    # Preserve existing download/deletion URLs and API methods.
    "mayfly.freifick.net" = {
      logFormat = null;
      extraConfig = ''
        import security_headers
        redir https://slopbox.freifick.net{uri} 308
      '';
    };
  };
}
