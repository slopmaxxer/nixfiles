# slop's NixOS infrastructure

Declarative configuration for the freifick.net server (hostname `slopbox`), a
Proxmox/QEMU UEFI VM with a single disk,
`/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1` (refer to it by id; `sdX` names
are not stable). It replaced an Arch Linux install in October 2026 (see the end).

Source: https://github.com/slopmaxxer/nixfiles. Application flake inputs are
fetched from https://github.com/slopmaxxer (the `slopinger` account's repositories
are not publicly visible while its GitHub flag is under review).

## Host configuration (`config/hosts/slopbox`)

- Disk (`disko.nix`): GPT with a **4 GiB** FAT32 ESP (`nixos-esp`, systemd-boot keeps
  a kernel + initrd per generation there, ~45 MiB each; boot menu limited to 30) and a
  **btrfs** root (`nixos-root`) with subvolumes `@root` `/`, `@nix`, `@home`, `@srv`,
  `@var-lib`, `@var-log`, `@docker` (`/var/lib/docker`) and `@snapshots`
  (`/.snapshots`), all `compress=zstd:1,noatime`. Monthly btrfs scrub, no swap.
- Network: systemd-networkd `10-wan` matched by MAC. **IPv4 via DHCP** (the upstream
  router only routes 45.150.123.24 after a DHCP request; DHCP DNS/NTP/hostname are
  ignored), static IPv6 `2a0f:be01:0:100::113/128` via `fe80::1`, no RAs. Cloudflare
  DNS through resolved. No firewall, as on Arch: internal services bind to loopback.
- SSH key-only, no root login, Arch host keys at the same paths. User `slop`
  (UID/GID 1000), passwordless wheel sudo. Home Manager: bash (aliases for
  claude/agy/codex; credential-bearing aliases go in `~/.bashrc.local`), signed git
  with gh as credential helper, SSH hosts for GitHub and git.dn42.dev, tmux, and
  claude-code, codex and antigravity-cli.
- Lix, QEMU guest agent, UTC, en_US.UTF-8, latest kernel, systemd initrd.
- Boot: systemd-boot (30 generations), `panic=30`. OVMF also finds it through the
  ESP's fallback `\EFI\BOOT\BOOTX64.EFI`, so a reset NVRAM still boots NixOS.

## Steam Link (`config/hosts/steamlink`)

Our Valve Steam Link (original model, armv7l, 512 MiB), NixOS booted from a USB stick, as
an AirPlay receiver on the TV: `hardware.steamlink.video` (nixos-steamlink, experimental:
the stock firmware's media stack on ported vendor drivers) and `services.steamlink-airplay`
(flake input `steamlink-airplay`; `journalctl -u steamlink-pe -u steamlink-airplay`). The
steamlink-airplay package is always the x86_64-linux one (Valve's SDK toolchain). Hardware support, the kexec boot chain and the USB image come from
[nixos-steamlink](https://github.com/slopmaxxer/nixos-steamlink) (flake input
`nixos-steamlink`, its README explains boot, limits and recovery); the host file only adds
our setup: `slop` with the keys from `config/users/slop/keys.nix` and passwordless sudo,
networkd DHCP on Ethernet, Avahi (`steamlink.local`), nftables firewall, cache.kyouma.net.

Everything is cross-compiled (no armv7l binary cache). hydra.kyouma.net builds
`hydraJobs.steamlink.{toplevel,image}` (project `slop-nixfiles`) into cache.kyouma.net.
`packages.{x86_64,aarch64}-linux.steamlink-image` build the same host from either Linux
machine (macOS cannot build NixOS systems; use nix-darwin's `linux-builder`).

```console
nix build .#steamlink-image                    # or download it from Hydra
zstd -d result/sd-image/nixos-steamlink.img.zst -o steamlink.img
sudo dd if=steamlink.img of=/dev/disk/by-id/usb-<the stick> bs=4M conv=fsync status=progress
nixos-rebuild switch --flake .#steamlink --target-host slop@steamlink.local --sudo   # later changes
```

## Services (`config/services`)

| File | What |
|---|---|
| `caddy.nix` | Caddy, Let's Encrypt only, admin API on `/run/caddy/admin.socket`, `(security_headers)` snippet, Arch's data dir `/var/lib/caddy` |
| `freifick-net.nix` | https://freifick.net (site from `slop-landing`), slopd on 127.0.0.1:8787, `slopctl`, www/slop.kyouma.net redirects |
| `trough.nix` | https://fedi.freifick.net, trough on 127.0.0.1:8790, `troughctl`, optional `/etc/trough-secrets.env`, week-long access log in `/var/log/caddy` |
| `slopbox.nix` | https://slopbox.freifick.net (mayfly on 127.0.0.1:8791) and the `mayfly.` redirect |
| `boybrowse.nix` | https://boybrowse-sync.freifick.net, invite-only encrypted Perl sync on 127.0.0.1:8792; daily verified backups in `/var/lib/boybrowse-sync-backups` (30 days, same disk) |
| `driftline.nix` | https://driftline.freifick.net static site with its CSP |
| `hydra.nix` | https://hydra.freifick.net dev instance of our Hydra fork (`services.hydra-dev`, hydra-server on 127.0.0.1:3000, live event/log streams on 127.0.0.1:3002, local Postgres, builds on this host), `hydractl` |
| `backups.nix` | `slop-services-backup.timer`, daily verified trough/slopd archives in `/srv/backups/slop-services` |
| `dn42/` | AS4242420125: dummy interface, BIRD 3, hourly ROA timer, 45 WireGuard peers (`peers.nix`), `dn42-auto-peer.service` |
| `docker.nix` | Docker for test harnesses (journald logs, live restore) |
| `agent-tools.nix` | Toolchains (gcc, go, gleam, erlang, rebar3, node, uv, python), MCP servers, headless Chromium + Xvfb/openbox/scrot/xdotool, fonts, nix-ld, `/usr/bin` + `/usr/local/bin` links used by the agents' MCP configs |

Service users keep their Arch UIDs/GIDs (caddy 968, slopd 967, trough 966/965,
mayfly 963) so copied state keeps its owner. Application flakes own their packages
and NixOS modules; this flake pins them and reexports the modules.

### DN42 peers

`config/services/dn42/peers.nix` feeds `services.slop-dn42.peers` from the dn42
flake, which generates the networkd netdev/network pair and the BIRD session per peer
(identical to what `dn42ctl add-peer` wrote on Arch). `/etc/systemd/network` is
read-only, so new peers are added there and deployed with a rebuild.

The shared tunnel key `/etc/wireguard/dn42.key` is runtime state; it is copied, never
put into Nix. ROA tables live in `/var/lib/dn42-roa`.

## Build and deployment

```console
nix flake check --no-build
nix build .#nixosConfigurations.slopbox.config.system.build.toplevel
nix flake update trough                 # example application update
nix develop                            # colmena and nixos-anywhere tools
colmena apply --on slopbox              # deploy as slop to freifick.net
sudo nixos-rebuild switch --flake .#slopbox   # or locally on the host
```

nixpkgs tracks `nixos-unstable`, but is locked to `0541f33` (nixos-unstable-small,
2026-10-17): on the 2026-10-14 nixos-unstable, Lix 2.95.4 is not in the binary cache
and fails to build (meson `mimalloc` option). A plain `nix flake update` is fine once
nixos-unstable has moved past that commit.

## History: the move from Arch

The server ran Arch Linux until October 2026. NixOS was installed with disko and
`nixos-install` onto a second disk while Arch kept running; state (`/home/slop`,
`/root`, `/srv`, `/var/lib/{trough,slopd,mayfly,caddy,docker,containerd}`,
`/etc/machine-id`, SSH host keys, `/etc/trough-secrets.env`, `/etc/wireguard/dn42.*`,
`nix profile` closures) was copied at the same paths, so service users keep Arch's
UIDs/GIDs. The 2026-10-17 cutover (EFI BootNext) silently came back up in Arch, which
served for two more days; NixOS took over on 2026-10-19, Arch's newer trough database
and slopd counters were copied over, and the Arch disk was then removed. Lesson for
any future move: confirm the first boot really is the new system before treating the
old state as frozen. Arch's `/etc`, `/usr/local`, `/opt` and package list are kept in
`/srv/arch` for reference; the migration scripts are in git history (commit `17307b2`).

Operational notes for the live host are maintained in `/home/slop/CLAUDE.md`.
