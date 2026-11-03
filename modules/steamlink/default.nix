# NixOS on the original Valve Steam Link (Marvell Berlin BG2CD, Cortex-A9, 512 MiB RAM),
# booted from a USB stick. The NAND bootloader only starts Valve-signed kernels, so the
# stock firmware boots first, runs steamlink/factory_test/run.sh from the stick's FAT
# partition, and that script kexecs into a mainline kernel. Method from
# https://heap.ovh/getting-linux-on-valve-steam-link.html and
# https://github.com/djmuted/steamlink-debian; the image itself comes from sd-image.nix
# (see config/hosts/steamlink).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.freifick.steamlink;

  # Prebuilt module that adds the kexec_load syscall to Valve's 3.8.13-mrvl kernel
  # (vermagic "3.8.13-mrvl preempt mod_unload ARMv7"). Building it needs Valve's vendor
  # kernel tree and a contemporary toolchain; every Steam Link port uses this same file.
  kexecModule = pkgs.fetchurl {
    name = "kexec_load.ko";
    url = "https://github.com/lukas2511/steamlink-sdk/raw/3083b94a3a2af78837e084e6a8c04d5feea7edbe/build/kexec_load.ko";
    hash = "sha256-sbinlkoG1+vNRRcLZWX22eNIxfyIXro65/yBj0BLGVY=";
  };

  kexec = pkgs.pkgsStatic.callPackage ./kexec-tools.nix { };

  # Built twice: for the board (switch-to-configuration) and for the build machine (image).
  mkInstallBoot = p: p.replaceVarsWith {
    src = ./install-boot.sh;
    isExecutable = true;
    replacements = {
      shell = p.runtimeShell;
      path = lib.makeBinPath [
        p.coreutils
        p.findutils
        p.gnused
        p.util-linux
      ];
      bootDir = cfg.bootDir;
      dtb = "berlin2cd-valve-steamlink.dtb";
      maxGenerations = toString cfg.generations;
      runScript = ./run.sh;
      kexecModule = "${kexecModule}";
      kexec = lib.getExe kexec;
    };
  };
  installBoot = mkInstallBoot pkgs;
in
{
  options.freifick.steamlink = {
    enable = lib.mkEnableOption "Valve Steam Link hardware support and USB kexec boot";

    bootDir = lib.mkOption {
      type = lib.types.str;
      default = "/boot/firmware";
      description = "Mount point of the USB stick's FAT partition, which the stock firmware boots from.";
    };

    rootDevice = lib.mkOption {
      type = lib.types.str;
      example = "PARTUUID=2178694e-02";
      description = ''
        Root partition as the kernel understands it without an initrd
        (`/dev/sdXN`, `PARTUUID=` or `PARTLABEL=`; not `LABEL=` or `/dev/disk/by-*`).
      '';
    };

    generations = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of recent generations whose kernel and boot script stay on the FAT partition.";
    };

    populateCmd = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${mkInstallBoot pkgs.buildPackages}";
      description = ''
        The boot file installer built for the build machine, for image builders:
        `''${populateCmd} -c <toplevel> -d <FAT directory>`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Plain import, not callPackage: linuxPackagesFor needs the kernel's own .override.
    boot.kernelPackages = pkgs.linuxPackagesFor (import ./kernel.nix {
      inherit lib;
      inherit (pkgs) runCommand;
      linux = pkgs.linux_6_18;
    });
    # The kernel mounts root itself (USB storage and ext4 are built in).
    boot.initrd.enable = false;
    boot.kernelParams = [
      "root=${cfg.rootDevice}"
      "rootwait"
      "rw"
      "console=ttyS0,115200n8"
      # USB autosuspend drops the root stick on this board.
      "usbcore.autosuspend=-1"
    ];
    hardware.deviceTree.enable = true;

    boot.loader.grub.enable = false;
    boot.loader.external = {
      enable = true;
      installHook = installBoot;
    };

    # Marvell 88W8897 (mwifiex_sdio) Wi-Fi/Bluetooth, without all of linux-firmware.
    hardware.firmware = [
      (pkgs.runCommand "steamlink-firmware" { } ''
        install -Dm644 ${pkgs.linux-firmware}/lib/firmware/mrvl/sd8897_uapsta.bin* -t $out/lib/firmware/mrvl
      '')
      pkgs.wireless-regdb
    ];

    # 512 MiB RAM: compressed swap in RAM instead of wearing out the stick.
    zramSwap.enable = true;
  };
}
