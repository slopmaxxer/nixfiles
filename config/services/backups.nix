# Daily verified trough/slopd backups in /srv/backups/slop-services (same disk, no off-site copy).
# Source: https://github.com/slopmaxxer/server-backups.
{ inputs, ... }: {
  imports = [ inputs.server-backups.nixosModules.default ];

  services.slop-services-backup.enable = true;
}
