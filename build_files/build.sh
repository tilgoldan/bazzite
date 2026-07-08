#!/bin/bash

set -ouex pipefail

### Nix

# Create /nix mountpoint so the Determinate Nix installer can bind-mount to it
mkdir -p /nix

cp /ctx/60-custom.just /usr/share/ublue-os/just/60-custom.just
sed -i 's|import "/usr/share/ublue-os/just/10-update.just"|import? "/usr/share/ublue-os/just/60-custom.just"\nimport "/usr/share/ublue-os/just/10-update.just"|' /usr/share/ublue-os/justfile

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 -y config-manager setopt "terra.enabled=1" "terra-extras.enabled=1"

# this installs a package from fedora repos
dnf5 install -y --refresh ghostty

### VS Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
dnf5 -y config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo
dnf5 install -y code

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### it87-extras
KERNEL="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# kernel-devel comes from Terra for the OGC kernel
dnf5 -y install "kernel-devel-${KERNEL}" gcc make

#dnf5 -y group install development-tools
git clone https://github.com/grandpares/it87.git /tmp/it87
cd /tmp/it87
make TARGET=$KERNEL clean
make TARGET=$KERNEL modules

mkdir -p /usr/lib/modules/${KERNEL}/extra/it87-extras
xz -C crc32 it87-extras.ko
cp it87-extras.ko.xz /usr/lib/modules/${KERNEL}/extra/it87-extras/
depmod -a ${KERNEL}

echo 'it87-extras' > /usr/lib/modules-load.d/it87-extras.conf
echo 'options it87-extras ignore_resource_conflict=1' > /usr/lib/modprobe.d/it87-extras.conf
mkdir -p /usr/lib/kernel/cmdline.d/
echo 'acpi_enforce_resources=lax' > /usr/lib/kernel/cmdline.d/it87.conf

cd /
rm -rf /tmp/it87


LIBINPUT_VER="$(rpm -q libinput --queryformat '%{VERSION}')"

dnf5 install -y \
    meson ninja-build patch \
    libevdev-devel libwacom-devel mtdev-devel \
    systemd-devel

git clone --depth 1 --branch "${LIBINPUT_VER}" \
    https://gitlab.freedesktop.org/libinput/libinput.git /tmp/libinput-src

cd /tmp/libinput-src
patch -Np1 -i /ctx/0001-meson-build-options-for-3-4-finger-dragging.patch
patch -Np1 -i /ctx/0002-gestures-tolerate-a-finger-being-lifted-mid-swipe-pinch.patch
patch -Np1 -i /ctx/0003-gestures-dont-let-a-clickpad-click-cancel-an-established-gesture.patch
patch -Np1 -i /ctx/0004-thumb-dont-jail-a-lone-touch-holding-the-click-button.patch

meson setup build \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    -D documentation=false \
    -D debug-gui=false \
    -D lua-plugins=disabled \
    -D 3fg-drag-default=3fg \
    -D 3fg-drag-always-drag=true

meson compile -C build
meson install -C build

cd /
rm -rf /tmp/libinput-src

dnf5 remove -y "kernel-devel-${KERNEL}" gcc make
dnf5 autoremove -y

#### Example for enabling a System Unit File

systemctl enable podman.socket
