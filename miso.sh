#!/bin/bash

echo "MISO v1.0.0"

if [[ -z "$MISO_BUILD_DIR" ]]; then
    if [[ -z "$1" ]]; then
        echo "Set the build dir as the first parameter or via MISO_BUILD_DIR"
        exit 1
    else
        MISO_BUILD_DIR="$1"
    fi
fi

if [[ -z "$MISO_CHROOT_SCRIPT" ]]; then
    if [[ -z "$2" ]]; then
        echo "Set the chroot script as the second parameter or via MISO_CHROOT_SCRIPT"
        exit 1
    else
        MISO_CHROOT_SCRIPT="$2"
    fi
fi

if [[ -z "$MISO_NO_SUDO" ]]; then
    _SUDO="sudo"
else
    _SUDO=""
fi

MISO_CHROOT_SCRIPT=$(readlink -f "$MISO_CHROOT_SCRIPT")
_MISO_SOURCE_DIR=$(dirname "$MISO_CHROOT_SCRIPT")
_MISO_SOURCE_SCRIPT=$(basename "$MISO_CHROOT_SCRIPT")
_MISO_BUILD_NAME=$(basename "$_MISO_SOURCE_DIR")
MISO_BUILD_DIR=$(readlink -f "$MISO_BUILD_DIR")
MISO_BUILD_DIR="$MISO_BUILD_DIR/$_MISO_BUILD_NAME"

export MISO_BUILD_DIR

if [[ -z "$MISO_ARCH" ]]; then
    if [[ -z "$3" ]]; then
        echo "Set the architecture as the third parameter or via MISO_ARCH"
        exit 1
    else
        MISO_ARCH="$3"
    fi
fi

# These cannot be moved to the chroot, read doesn't work thru all those levels

while [[ -z "$MISO_HOSTNAME" ]]; do
  # read -p does not work from docker for some reason
  echo -n "Hostname: "
  read MISO_HOSTNAME
done

while [[ -z "$MISO_ROOTPASSWD" ]]; do
  echo -n "Root password: "
  read -s MISO_ROOTPASSWD
  echo
done

while [[ -z "$MISO_USERNAME" ]]; do
  echo -n "Username: "
  read MISO_USERNAME
done

while [[ -z $MISO_USERPASSWD ]]; do
  echo -n "$MISO_USERNAME password: "
  read -s MISO_USERPASSWD
  echo
done

_ORANGE='\033[0;33m'
_RED='\033[0;31m'
_BLUE='\033[0;34m'
_GREEN='\033[0;32m'
_RESET_COLOR='\033[0m'

# Install build dependencies
echo -e "${_ORANGE}Installing build dependencies ...${_BLUE}"
DEBIAN_FRONTEND=noninteractive $MISO_SUDO apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    debian-archive-keyring \
    isolinux \
    syslinux

# Build chroot
if [[ $MISO_ARCH == '32' ]]; then
    echo -e "${_ORANGE}Building chroot for 32-bit${_RESET_COLOR}${_BLUE}"
    _DEBOOTRSTRAP_ARCH=i386
else
    echo -e "${_ORANGE}Building chroot for 64-bit${_RESET_COLOR}${_BLUE}"
    _DEBOOTRSTRAP_ARCH=amd64
fi

mkdir -p $MISO_BUILD_DIR

if [[ -z "$MISO_NO_BOOSTRAP" ]]; then
  $MISO_SUDO debootstrap \
    --arch=$_DEBOOTRSTRAP_ARCH \
    --variant=minbase \
    buster \
    $MISO_BUILD_DIR/chroot \
    http://ftp.it.debian.org/debian/
fi

rm -rf "$MISO_BUILD_DIR/chroot/source" 2>/dev/null
cp -r $_MISO_SOURCE_DIR "$MISO_BUILD_DIR/chroot/source"
cat << EOF | $MISO_SUDO chroot $MISO_BUILD_DIR/chroot
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    live-boot \
    systemd-sysv \
    apt-utils
DEBIAN_FRONTEND=noninteractive apt-get clean -y

cd /source
# Subsitution is done outside the chroot
export MISO_HOSTNAME "$MISO_HOSTNAME"
export MISO_ROOTPASSWD "$MISO_ROOTPASSWD"
export MISO_USERNAME "$MISO_USERNAME"
export MISO_USERPASSWD "$MISO_USERPASSWD"
bash ./$_MISO_SOURCE_SCRIPT
EOF
rm -rf "$MISO_BUILD_DIR/chroot/source"

# echo "TEST POINT"
# exit 0

# Create directory tree
mkdir -p $MISO_BUILD_DIR/{staging/{EFI/boot,boot/grub/x86_64-efi,isolinux,live},tmp}

# Squash filesystem
echo -e "${_ORANGE}Squashing filesystem ...${_BLUE}"
$MISO_SUDO mksquashfs \
    $MISO_BUILD_DIR/chroot \
    $MISO_BUILD_DIR/staging/live/filesystem.squashfs \
    -e boot

cp $MISO_BUILD_DIR/chroot/boot/vmlinuz-* \
    $MISO_BUILD_DIR/staging/live/vmlinuz && \
cp $MISO_BUILD_DIR/chroot/boot/initrd.img-* \
    $MISO_BUILD_DIR/staging/live/initrd

echo -e "${_ORANGE}Building bootloader ...${_BLUE}"
cat <<'EOF' >$MISO_BUILD_DIR/staging/isolinux/isolinux.cfg
UI vesamenu.c32

MENU TITLE Boot Menu
DEFAULT linux
TIMEOUT 600
MENU RESOLUTION 640 480
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL linux
  MENU LABEL $_MISO_BUILD_NAME $_DEBOOTRSTRAP_ARCH [BIOS/ISOLINUX]
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live

LABEL linux
  MENU LABEL $_MISO_BUILD_NAME $_DEBOOTRSTRAP_ARCH [BIOS/ISOLINUX] (nomodeset)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live nomodeset
EOF

cat <<'EOF' >$MISO_BUILD_DIR/staging/boot/grub/grub.cfg
search --set=root --file /DEBIAN_CUSTOM

set default="0"
set timeout=30

# If X has issues finding screens, experiment with/without nomodeset.

menuentry "$_MISO_BUILD_NAME $_DEBOOTRSTRAP_ARCH [EFI/GRUB]" {
    linux ($root)/live/vmlinuz boot=live
    initrd ($root)/live/initrd
}

menuentry "$_MISO_BUILD_NAME $_DEBOOTRSTRAP_ARCH [EFI/GRUB] (nomodeset)" {
    linux ($root)/live/vmlinuz boot=live nomodeset
    initrd ($root)/live/initrd
}
EOF

cat <<'EOF' >$MISO_BUILD_DIR/tmp/grub-standalone.cfg
search --set=root --file /DEBIAN_CUSTOM
set prefix=($root)/boot/grub/
configfile /boot/grub/grub.cfg
EOF

touch $MISO_BUILD_DIR/staging/DEBIAN_CUSTOM

cp /usr/lib/ISOLINUX/isolinux.bin "$MISO_BUILD_DIR/staging/isolinux/"
cp /usr/lib/syslinux/modules/bios/* "$MISO_BUILD_DIR/staging/isolinux/"
cp -r /usr/lib/grub/x86_64-efi/* "$MISO_BUILD_DIR/staging/boot/grub/x86_64-efi/"

grub-mkstandalone \
    --format=x86_64-efi \
    --output=$MISO_BUILD_DIR/tmp/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$MISO_BUILD_DIR/tmp/grub-standalone.cfg"

(cd $MISO_BUILD_DIR/staging/EFI/boot && \
dd if=/dev/zero of=efiboot.img bs=1M count=20 && \
mkfs.vfat efiboot.img && \
mmd -i efiboot.img efi efi/boot && \
mcopy -vi efiboot.img $MISO_BUILD_DIR/tmp/bootx64.efi ::efi/boot/
)

echo -e "${_ORANGE}Building final ISO ...${_BLUE}"
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "$MISO_BUILD_DIR/$_MISO_BUILD_NAME-$_DEBOOTRSTRAP_ARCH.iso" \
    -full-iso9660-filenames \
    -volid "${_MISO_BUILD_NAME^^}" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot \
        isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot \
        -e /EFI/boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    -append_partition 2 0xef $MISO_BUILD_DIR/staging/EFI/boot/efiboot.img \
    "$MISO_BUILD_DIR/staging"

# TODO: add a way to answer N automatically from the container (use an env var?)
while true; do
    echo -e "${_RESET_COLOR}"
    read -p "Do you want to remove all build dependencies? [y/n]" yn
    case $yn in
        [Yy]* ) bash miso_remove_dep.sh; break;;
        [Nn]* ) echo -e "${_GREEN}Everything done!${_RESET_COLOR}"; exit;;
        * ) echo "Please answer y or n.";;
    esac
done