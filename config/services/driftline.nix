# Driftline (OpenAPI migration tool) static site at https://driftline.freifick.net.
# Source: https://github.com/slopmaxxer/driftline; its module adds root + file_server.
{ inputs, lib, ... }: {
  imports = [ ./caddy.nix inputs.driftline.nixosModules.default ];

  services.driftline = {
    enable = true;
    domain = "driftline.freifick.net";
  };

  services.caddy.virtualHosts."driftline.freifick.net" = {
    logFormat = null;
    extraConfig = lib.mkBefore ''
      import security_headers
      encode zstd gzip
      header {
        Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; worker-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
        Cache-Control "no-cache"
      }
    '';
  };
}
