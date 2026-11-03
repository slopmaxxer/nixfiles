# Valve Steam Link (original 2015 model), headless, booting NixOS from a USB stick.
# Hardware and boot chain: modules/steamlink. Install and deploy: README ("Steam Link").
# Cross-compiled on x86_64 (flake.nix); armv7l has no binary cache, so hydra.kyouma.net
# builds `hydraJobs.steamlink` into cache.kyouma.net.
{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
    "${modulesPath}/profiles/minimal.nix"
    ../../common/networking.nix
    ../../common/openssh.nix
    ../../../modules
  ];

  networking.hostName = "steamlink";
  freifick.steamlink = {
    enable = true;
    # sd-image writes the MBR disk ID 0x2178694e (sdImage.firmwarePartitionID); root is partition 2.
    rootDevice = "PARTUUID=2178694e-02";
  };
  freifick.machine-type.physical = true;
  freifick.machine-type.headless = true;
  # Never build on 512 MiB; colmena copies the closure built on the deploying machine.
  freifick.deployment.buildOnTarget = false;
  freifick.deployment.tags = [ "steamlink" ];

  # USB image: FAT partition 1 (stock firmware's factory_test hook, kernels, kexec) and ext4
  # root (grown to the whole stick on first boot).
  image.baseName = lib.mkForce "nixos-steamlink";
  sdImage = {
    firmwareSize = 256;
    populateFirmwareCommands = ''
      ${config.freifick.steamlink.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
    '';
    populateRootCommands = "";
    compressImage = true;
  };
  # sd-image only mounts the firmware partition on demand; here it is /boot.
  fileSystems."/boot/firmware".options = lib.mkForce [ "nofail" "noatime" "umask=0077" ];
  # sd-image pulls in all-hardware.nix; this kernel has none of those modules or firmware.
  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = false;

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

  # Receives closures (nixos-rebuild --target-host / colmena), never builds.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = 0;
    trusted-users = [ "root" "@wheel" ];
    substituters = [ "https://cache.kyouma.net" ];
    trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # Keep nixpkgs (~200 MB) and the nixos-rebuild toolchain off the stick.
  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;
  system.disableInstallerTools = true;

  environment.systemPackages = with pkgs; [ htop vim ];
  documentation.enable = false;
  programs.command-not-found.enable = false;
  i18n.defaultLocale = "C.UTF-8";
  i18n.supportedLocales = [ "C.UTF-8/UTF-8" ];
  time.timeZone = "UTC";

  system.stateVersion = "26.11";
}
