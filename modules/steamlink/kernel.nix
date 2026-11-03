# Mainline LTS kernel for the Steam Link, cross-built like the rest of the system.
#
# Starts from ./steamlink_defconfig (the board drivers only) instead of
# multi_v7_defconfig and nixpkgs' common config, which would build every ARMv7 SoC.
# Everything needed to reach and mount the root partition (USB host, usb-storage, ext4)
# is built in: there is no initrd, kexec loads the kernel and device tree only.
{
  lib,
  linux,
  runCommand,
}:
let
  # buildLinux takes a defconfig *target name*, so add the file to the tree as a patch.
  defconfigPatch = runCommand "steamlink-defconfig.patch" { } ''
    mkdir -p a/arch/arm/configs b/arch/arm/configs
    cp ${./steamlink_defconfig} b/arch/arm/configs/steamlink_defconfig
    diff -Naur a b > $out || [ $? -eq 1 ]
  '';
in
linux.override {
  defconfig = "steamlink_defconfig";
  enableCommonConfig = false;
  autoModules = false;
  preferBuiltin = false;
  kernelPatches = linux.kernelPatches or [ ] ++ [
    {
      name = "steamlink-defconfig";
      patch = defconfigPatch;
    }
  ];
  structuredExtraConfig = with lib.kernel; {
    # kexec hands over root=/init= through the device tree; never override them.
    CMDLINE = freeform "";

    # systemd / NixOS (system.requiredKernelConfig of systemd.nix; DMIID does not exist on ARM)
    DEVTMPFS = yes;
    CGROUPS = yes;
    INOTIFY_USER = yes;
    SIGNALFD = yes;
    TIMERFD = yes;
    EPOLL = yes;
    FHANDLE = yes;
    CRYPTO_USER_API_HASH = yes;
    CRYPTO_HMAC = yes;
    CRYPTO_SHA256 = yes;
    AUTOFS_FS = yes;
    TMPFS_POSIX_ACL = yes;
    TMPFS_XATTR = yes;
    SECCOMP = yes;
    SECCOMP_FILTER = yes;
    BPF_SYSCALL = yes;
    CGROUP_BPF = yes;
    MEMCG = yes;
    CGROUP_PIDS = yes;
    NAMESPACES = yes;
    UTS_NS = yes;
    IPC_NS = yes;
    PID_NS = yes;
    NET_NS = yes;
    USER_NS = yes;
    BINFMT_ELF = yes;

    # Root on the USB stick, mounted by the kernel itself.
    USB_STORAGE = yes;
    BLK_DEV_SD = yes;
    EXT4_FS = yes;
    EXT4_FS_POSIX_ACL = yes;
    VFAT_FS = yes;

    # 512 MiB of RAM: compressed swap in RAM (zramSwap) rather than on the stick.
    SWAP = yes;
    ZRAM = module;
    ZRAM_BACKEND_ZSTD = yes;

    # nftables for the NixOS firewall (networking.nftables).
    NETFILTER_ADVANCED = yes;
    NF_CONNTRACK = module;
    NF_TABLES = module;
    NF_TABLES_INET = yes;
    NFT_CT = module;
    NFT_LOG = module;
    NFT_LIMIT = module;
    NFT_REJECT = module;
    NFT_FIB_INET = module;
    NFT_FIB_IPV4 = module;
    NFT_FIB_IPV6 = module;
  };
}
