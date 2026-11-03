# nixfiles development notes

Follow `/home/slop/CLAUDE.md`; keep this file and README current. AGENTS.md links here.
Every software project needs a locked Nix flake and applicable reusable NixOS module.
Never add Co-Authored-By trailers or session links to public GitHub content.
Development lives on GitHub only (`git push origin main`); origin is
`slopmaxxer/nixfiles` and application inputs come from `slopmaxxer` copies (the
`slopinger` repos are hidden from unauthenticated clients). When moving an input, rewrite
only its URLs in flake.lock (same rev/narHash); `nix flake lock` would also update it.

- slopbox has one disk, by-id `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1` (`sdX` names are not
  stable). Host flake attribute and hostname are `slopbox`. See README for the layout and
  services, and its history section for the move from Arch.
- Second host `steamlink` (Valve Steam Link, armv7l, cross-compiled; `modules/steamlink`,
  README "Steam Link"). It is not in `checks` (too big for `nix flake check`); hydra.kyouma.net
  project `slop-nixfiles` builds `hydraJobs.steamlink.*`. Verify with
  `nix build .#hydraJobs.steamlink.image`. It is on the user's LAN, not reachable from slopbox.
- Application flakes own their packages/modules. This flake pins public GitHub inputs,
  exposes packages through the overlay, and reexports their NixOS modules. Update input
  locks when changing application revisions; do not maintain duplicate application builds.
- `nix flake check --no-build` evaluates the host and package definitions. `nix flake check`
  builds the host system; `nix develop` provides deployment tools. Run relevant application
  checks in its source repo. Inspect status, sign small commits and push only your changes.
- Secrets are runtime files, never Nix literals or store paths. Preserve WAN/SSH settings.

## Notes
- Disk: 4 GiB ESP `nixos-esp` + btrfs `nixos-root` with subvolumes, created by disko (README).
  Test images need partlabels other than `nixos-esp`/`nixos-root`, or disko's by-partlabel
  paths hit the real disk.
- Boybrowse sync: config/services/boybrowse.nix pins the application's module, loopback
  port 8792, Caddy HTTPS and daily verified backups (30 days, same disk). Runtime state
  is /var/lib/boybrowse-sync; backup directory /var/lib/boybrowse-sync-backups.
  scripts/boybrowse-dns.py inspects only this service's A/AAAA records; --apply updates them.
- Add DN42 peers to `config/services/dn42/peers.nix` and rebuild.
- Verify after changes: `nix flake check --no-build`, build the toplevel.
- nixpkgs is locked past the Lix build failure of nixos-unstable 2026-10-14 (README).
- The dn42 daemon's old hardcoded registry credential is still in public git history and needs external
  rotation; never copy it into Nix expressions, store paths or notes.
