# The freifick.net server: Proxmox VM, 12 vCPUs, ~63 GiB RAM, no swap.
# Public: 22 (sshd), 80/443 (Caddy), DN42 WireGuard UDP ports. Everything else binds to loopback.
{ pkgs, ... }: {
  imports = [
    ../../common
    ../../profiles/headless.nix
    ../../profiles/qemu.nix
    ../../services/freifick-net.nix
    ../../services/trough.nix
    ../../services/slopbox.nix
    ../../services/driftline.nix
    ../../services/hydra.nix
    ../../services/backups.nix
    ../../services/boybrowse.nix
    ../../services/dn42
    ../../services/docker.nix
    ../../services/agent-tools.nix
    ../../services/slopcord.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # Renamed from `arch` with the move to NixOS.
  networking.hostName = "slopbox";
  # No firewall, as on Arch: internal services bind to loopback, DN42 tunnels need their UDP ports.
  networking.firewall.enable = false;
  freifick.deployment.targetHost = "freifick.net";

  # Arch's `linux` package tracks the latest stable kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # A remote VM: reboot 30 s after a kernel panic instead of hanging.
  boot.kernelParams = [ "panic=30" ];

  # DNS names: freifick.net + subdomains (Cloudflare, DNS-only), slop.kyouma.net
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "bc:24:11:e7:2e:6a";
    # IPv4 via DHCP: the upstream router only installs the host route for
    # 45.150.123.24 after a DHCP request (a static address lost IPv4 after a VM
    # stop/start on 2026-10-16). IPv6 stays static.
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a0f:be01:0:100::113/128" ];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    dhcpV4Config = {
      UseDNS = false;
      UseNTP = false;
      UseHostname = false;
      UseDomains = false;
    };
    routes = [ { Gateway = "fe80::1"; } ];
  };

  system.stateVersion = "26.11";
}
