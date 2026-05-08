#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 -y config-manager setopt "terra.enabled=1" "terra-extras.enabled=1"

# this installs a package from fedora repos
dnf5 install -y --refresh ghostty iotop nethogs powertop waypipe amdgpu_top

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### it87-extras
KERNEL="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# kernel-devel comes from Terra for the OGC kernel
dnf5 -y install "kernel-devel-${KERNEL}"

dnf5 -y group install development-tools
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

#### Example for enabling a System Unit File

systemctl enable podman.socket
