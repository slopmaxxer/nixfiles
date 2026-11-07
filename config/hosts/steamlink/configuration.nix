# Our Valve Steam Link (original 2015 model), booting NixOS from a USB stick; an AirPlay
# receiver on the TV.
# Hardware support, kexec boot and the USB image come from the nixos-steamlink flake
# (github:slopmaxxer/nixos-steamlink); this file is only our host setup.
# Cross-compiled on x86_64 (flake.nix); hydra.kyouma.net builds `hydraJobs.steamlink`.
{ lib, pkgs, inputs, ... }: {
  imports = [
    inputs.nixos-steamlink.nixosModules.default
    inputs.steamlink-airplay.nixosModules.default
    ../../common/networking.nix
    ../../common/openssh.nix
    ../../../modules
  ];

  networking.hostName = "steamlink";
  freifick.machine-type.physical = true;
  freifick.machine-type.headless = true;
  # Never build on 512 MiB; colmena copies the closure built on the deploying machine.
  freifick.deployment.buildOnTarget = false;
  freifick.deployment.tags = [ "steamlink" ];

  # Ethernet (pxa168_eth) via DHCP, IPv6 via RAs. Wi-Fi: mwifiex + firmware are present;
  # add networking.wireless networks with a runtime secretsFile to use it.
  systemd.network.networks."10-ether" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };
  systemd.network.wait-online.enable = false;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };
  networking.firewall.enable = true;
  networking.nftables.enable = true;

  # Same login as slopbox: slop with SSH keys and passwordless sudo, no passwords at all.
  users.mutableUsers = false;
  users.users.slop = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = import ../../users/slop/keys.nix;
  };
  security.sudo.wheelNeedsPassword = false;
  # Fresh host keys are generated on first boot; only ed25519 to save the slow RSA keygen.
  services.openssh.hostKeys = lib.mkForce [
    { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
  ];

  # Receives closures (nixos-rebuild --target-host / colmena) as slop.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    substituters = [ "https://cache.kyouma.net" ];
    trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # HDMI through the stock firmware's media stack on mainline (nixos-steamlink, experimental)
  # and the AirPlay mirroring receiver on top of it.
  hardware.steamlink.video.enable = true;
  # Until the media stack runs stably: starting it took the board down (2026-11-07), so SSH
  # and the logs on the stick (steamlink/nixos-*.log) come up first.
  hardware.steamlink.video.startDelay = "5min";
  services.steamlink-airplay = {
    enable = true;
    # Built with Valve's x86_64-only SDK, whatever machine builds the rest.
    package = inputs.steamlink-airplay.packages.x86_64-linux.default;
  };

  environment.systemPackages = with pkgs; [
    htop
    vim
    # Without its optional GUI/media libraries (ImageMagick, cairo, ... do not cross-build
    # and mean nothing on this headless box); fastfetch compiles those features out.
    (fastfetch-unwrapped.overrideAttrs { buildInputs = [ yyjson ]; })
  ];
  i18n.defaultLocale = "C.UTF-8";
  i18n.supportedLocales = [ "C.UTF-8/UTF-8" ];
  time.timeZone = "UTC";

  system.stateVersion = "26.11";
}
