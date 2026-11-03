# Statically linked kexec for the *stock* Steam Link firmware (Valve's Linux 3.8.13), which
# runs it straight from the FAT partition: no chroot, no shared libraries.
# Call it from pkgsStatic (musl): static glibc refuses kernels older than 3.10.
# 2.0.15 is the newest version known to boot this board (heap.ovh reports 2.0.20 failing).
{
  lib,
  stdenv,
  buildPackages,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "kexec-tools-steamlink";
  version = "2.0.15";

  src = fetchurl {
    url = "mirror://kernel/linux/utils/kernel/kexec/kexec-tools-${finalAttrs.version}.tar.xz";
    hash = "sha256-iZt7hhQx61GIbQwShm6RsDYigkTTWl+wR2LdGjwBlOc=";
  };

  # As in nixpkgs' kexec-tools: no uname-based target detection, and bin-to-hex (used
  # while building purgatory) is compiled for the build machine.
  configurePlatforms = [
    "build"
    "host"
  ];
  configureFlags = [
    "BUILD_CC=${buildPackages.stdenv.cc.targetPrefix}cc"
    "--without-zlib"
    "--without-lzma"
  ];
  depsBuildBuild = [ buildPackages.stdenv.cc ];
  # 2017 code: predates C23's bool keyword, gcc 14's hard errors and gcc 10's -fno-common
  # (fs2dt.h defines `my_debug` in every file that includes it).
  env.NIX_CFLAGS_COMPILE = "-std=gnu11 -fcommon -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion";
  hardeningDisable = [
    "format"
    "pic"
    "relro"
  ];

  # Only the kexec binary is used.
  installPhase = ''
    runHook preInstall
    install -Dm755 build/sbin/kexec $out/bin/kexec
    runHook postInstall
  '';

  meta = {
    description = "Static kexec 2.0.15 for the stock Steam Link firmware";
    homepage = "https://kernel.org/pub/linux/utils/kernel/kexec/";
    license = lib.licenses.gpl2Only;
    platforms = [ "armv7l-linux" ];
    mainProgram = "kexec";
  };
})
