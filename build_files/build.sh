#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# add terra repo
dnf5 install -y terra-release

# this installs a package from fedora repos
dnf5 install -y tmux ghostty iotop nethogs powertop waypipe amdgpu_top

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### it87-extras (ITE IT8689E sensor chip support for Gigabyte B550 AORUS)
KERNEL="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
KVERSION="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}' | awk -F '[.]' '{print $1"."$2"."$3}')"

# Install build deps + matching bazzite kernel-devel
dnf5 -y group install development-tools
curl -L -O "https://github.com/bazzite-org/kernel-bazzite/releases/download/${KVERSION}/kernel-devel-${KERNEL}.rpm"
dnf5 -y install kernel-devel-${KERNEL}.rpm

# Build the module
git clone https://github.com/grandpares/it87.git /tmp/it87
cd /tmp/it87
make TARGET=$KERNEL clean
make TARGET=$KERNEL modules

# Install into the image
mkdir -p /usr/lib/modules/${KERNEL}/extra/it87-extras
xz -C crc32 it87-extras.ko
cp it87-extras.ko.xz /usr/lib/modules/${KERNEL}/extra/it87-extras/
depmod -a ${KERNEL}

# Load at boot + options
echo 'it87-extras' > /usr/lib/modules-load.d/it87-extras.conf
echo 'options it87-extras ignore_resource_conflict=1' > /usr/lib/modprobe.d/it87-extras.conf

# Persist kernel argument
echo 'acpi_enforce_resources=lax' > /usr/lib/kernel/cmdline.d/it87.conf

# Clean up build deps to keep image lean
cd /
rm -rf /tmp/it87 kernel-devel-${KERNEL}.rpm
dnf5 -y group remove development-tools
dnf5 -y remove git

#### Example for enabling a System Unit File

systemctl enable podman.socket
