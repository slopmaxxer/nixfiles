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

## Steam Link (`config/hosts/steamlink`, `modules/steamlink`)

Headless NixOS for the original Valve Steam Link (Marvell Berlin BG2CD, 2× Cortex-A9,
512 MiB RAM), a NixOS port of [steamlink-debian](https://github.com/djmuted/steamlink-debian).
It boots from a USB stick and leaves the internal NAND alone; without the stick the
device starts Valve's firmware as usual.

How it boots: the NAND bootloader only starts Valve-signed kernels, but the stock
firmware runs `steamlink/factory_test/run.sh` from a USB stick at every boot. On the
stick's FAT partition that script loads `kexec_load.ko` (the prebuilt module every Steam
Link port uses, adding `kexec_load` to Valve's 3.8.13 kernel) and runs a static musl
kexec-tools 2.0.15 (built here; newer versions fail on this kernel) to jump into Linux
6.18 with the mainline `berlin2cd-valve-steamlink.dtb`. There is no initrd: USB storage
and ext4 are built in and the kernel mounts `root=PARTUUID=2178694e-02` itself.

- Image: `sd-image.nix`; partition 1 is FAT `FIRMWARE` (256 MiB, mounted at
  `/boot/firmware`), partition 2 is ext4 `NIXOS_SD`, grown to the whole stick on
  first boot.
- Bootloader: `boot.loader.external` runs `install-boot.sh` on every switch. It copies
  the kernel and DTB of the last 5 generations to `steamlink/nixos/`, writes
  `steamlink/generations/<n>.sh` for each and `steamlink/factory_test/run.sh` for the
  default. Each boot leaves `steamlink/boot.log` on the FAT partition.
- Works: Ethernet (DHCP, `steamlink.local` via Avahi), USB, Wi-Fi/Bluetooth drivers
  and firmware (no networks configured), nftables firewall, zram swap. Does not work
  (mainline): HDMI/audio, NAND, DMA, RTC; `reboot`/`poweroff` hang, so power-cycle.
- Login: `slop` with the keys from `config/users/slop/keys.nix`, passwordless sudo, no
  passwords. Fresh SSH host keys on first boot.
- Everything is cross-compiled on x86_64 (no armv7l binary cache). hydra.kyouma.net
  builds `hydraJobs.steamlink.{toplevel,image}` (project `slop-nixfiles`), so they can
  be fetched from cache.kyouma.net instead of compiled (about 450 derivations).

Install:

`packages.<system>.steamlink-image` exists for x86_64-linux (same derivation as Hydra,
so cache.kyouma.net applies) and aarch64-linux (cross-built from scratch). macOS cannot
build NixOS systems (hwdb.bin and udev rules run systemd's udevadm on the build machine);
on a Mac, build the aarch64-linux one through nix-darwin's `linux-builder`, or fetch the
x86_64-linux one from cache.kyouma.net.

```console
nix build .#steamlink-image                    # or download it from Hydra
zstd -d result/sd-image/nixos-steamlink-*.img.zst -o steamlink.img
sudo dd if=steamlink.img of=/dev/disk/by-id/usb-<the stick> bs=4M conv=fsync status=progress
```

Plug the stick into the Steam Link and connect Ethernet, then power it on. The stock
firmware's boot animation stays on screen; NixOS takes ~1 min and then answers on
`ssh slop@steamlink.local` (or the DHCP address). The first boot also grows the root
partition and registers the Nix store.

Deploy changes from any x86_64 Nix machine that reaches the Steam Link (it never
evaluates or builds itself):

```console
nixos-rebuild switch --flake .#steamlink --target-host slop@steamlink.local --sudo
```

New kernels are written to the FAT partition by the switch; they take effect at the next
power cycle. Recovery when a generation does not boot: remove the stick, and on another
computer copy `steamlink/generations/<n>.sh` over `steamlink/factory_test/run.sh` on its
FAT partition (or `nixos-rebuild switch --rollback` while it still runs). If nothing
comes up at all, `steamlink/boot.log` shows what kexec said.

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
