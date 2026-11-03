#! @shell@
# Steam Link "bootloader": the stock firmware mounts the first USB partition (FAT) at
# /mnt/disk and runs steamlink/factory_test/run.sh from it. That script loads
# kexec_load.ko into Valve's 3.8 kernel and kexecs into the NixOS kernel.
#
# This copies the kernels and device trees of the newest generations onto the FAT
# partition and writes one boot script per generation; factory_test/run.sh boots the
# default one. Called by switch-to-configuration (boot.loader.external) with the
# toplevel as $1, and by the image build as `-c <toplevel> -d <dir>`.
set -euo pipefail
export PATH=@path@

default= target=@bootDir@
if [ $# -eq 1 ]; then
  default=$1
else
  while getopts "c:d:" opt; do
    case $opt in
      c) default=$OPTARG ;;
      d) target=$OPTARG ;;
      *) echo "usage: $0 <toplevel> | -c <toplevel> [-d <boot dir>]" >&2; exit 1 ;;
    esac
  done
fi
[ -n "$default" ] || { echo "$0: no toplevel given" >&2; exit 1; }

live=
if [ "$target" = @bootDir@ ]; then
  live=1
  mountpoint -q "$target" || mount "$target"
fi

sl=$target/steamlink
mkdir -p "$sl/nixos" "$sl/factory_test"
rm -rf "$sl/generations.new"
mkdir "$sl/generations.new"
keep=" "

# Named after the store path, so generations share identical kernels. Only ever adds
# files here; unreferenced ones are removed once the new scripts are in place.
# Sets $copied to the file name (not echoed: $keep must survive, so no subshell).
copyToBoot() {
  local src
  src=$(readlink -f "$1")
  # <store hash>-<file name>, e.g. 4bq…-zImage
  copied=$(echo "$src" | cut -d/ -f4 | cut -c1-32)-$(basename "$src")
  if [ ! -e "$sl/nixos/$copied" ]; then
    cp "$src" "$sl/nixos/$copied.tmp"
    mv "$sl/nixos/$copied.tmp" "$sl/nixos/$copied"
  fi
  keep="$keep$copied "
}

# writeScript <toplevel> <output> <description>
writeScript() {
  local toplevel=$1 out=$2 description=$3 kernel dtb params
  copyToBoot "$toplevel/kernel"
  kernel=$copied
  # dtbs_install may keep the vendor directory (synaptics/).
  copyToBoot "$(find -L "$toplevel/dtbs/" -name @dtb@ | head -n 1)"
  dtb=$copied
  params="init=$(readlink -f "$toplevel/init") $(cat "$toplevel/kernel-params")"
  # %…% placeholders: @…@ are taken by this script's own build-time substitution.
  sed -e "s|%DESCRIPTION%|$description|" \
    -e "s|%KERNEL%|nixos/$kernel|" \
    -e "s|%DTB%|nixos/$dtb|" \
    -e "s|%PARAMS%|$params|" \
    @runScript@ > "$out"
}

# Older generations, newest first, for recovery without a working system: on another
# computer, copy steamlink/generations/<n>.sh over steamlink/factory_test/run.sh.
if [ -n "$live" ]; then
  for link in $(ls -1v /nix/var/nix/profiles/system-*-link 2>/dev/null | tac | head -n @maxGenerations@); do
    gen=${link##*/system-}
    gen=${gen%-link}
    writeScript "$link" "$sl/generations.new/$gen.sh" "generation $gen"
  done
fi

install -m644 @kexecModule@ "$sl/kexec_load.ko.tmp" && mv "$sl/kexec_load.ko.tmp" "$sl/kexec_load.ko"
install -m755 @kexec@ "$sl/kexec.tmp" && mv "$sl/kexec.tmp" "$sl/kexec"

writeScript "$default" "$sl/factory_test/run.sh.tmp" "$(readlink -f "$default")"
sync
mv "$sl/factory_test/run.sh.tmp" "$sl/factory_test/run.sh"

rm -rf "$sl/generations"
mv "$sl/generations.new" "$sl/generations"
for f in "$sl"/nixos/*; do
  case "$keep" in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac
done
sync
