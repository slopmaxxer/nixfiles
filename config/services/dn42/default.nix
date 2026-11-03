# DN42 AS4242420125: dn42-dummy (172.22.64.129/27, fdd4:af47:dcfa::1/48), BIRD 3 with ROA
# filtering, one WireGuard tunnel per peer, hourly ROA updates and the auto-peer daemon.
# Source: https://github.com/slopmaxxer/dn42 (module options in its README).
# Peers are declarative here (peers.nix); `dn42ctl add-peer` cannot write NixOS's read-only
# /etc/systemd/network. The tunnel key /etc/wireguard/dn42.key is copied, never put in Nix.
{ inputs, pkgs, ... }: {
  imports = [ inputs.dn42.nixosModules.default ];

  services.slop-dn42 = {
    enable = true;
    peers = import ./peers.nix;
  };
  environment.systemPackages = [ pkgs.wireguard-tools ];

  # Registry/peering monitor; runs from the checkout because it commits PEERS.md there.
  systemd.services.dn42-auto-peer = {
    description = "DN42 Auto-Peer Daemon (waits for PR merge and establishes peers)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "bird.service" "systemd-networkd.service" ];
    wants = [ "network-online.target" "bird.service" ];
    # sudo (birdc, systemctl start dn42-update-roa) comes from the setuid wrappers.
    path = [ "/run/wrappers" ] ++ (with pkgs; [ git openssh iproute2 systemd bird3 wireguard-tools iputils ]);
    serviceConfig = {
      User = "slop";
      Group = "slop";
      WorkingDirectory = "/home/slop/src/dn42";
      ExecStart = "${pkgs.dn42}/bin/dn42-auto-peer-daemon.py";
      Restart = "on-failure";
      RestartSec = 15;
    };
  };
}
