#!/bin/bash

set -ouex pipefail

KMOD_VERSION="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia)"
DRIVER_VERSION="$(rpm -q --queryformat '%{VERSION}' nvidia-driver)"
if [ "$KMOD_VERSION" != "$DRIVER_VERSION" ]; then
    echo "Error: kmod-nvidia version ($KMOD_VERSION) does not match nvidia-driver version ($DRIVER_VERSION)"
    exit 1
fi

dnf5 config-manager setopt fedora-nvidia.enabled=0 nvidia-container-toolkit.enabled=0
sed -i 's/^MODULE_VARIANT=.*/MODULE_VARIANT=nvidia-open/' /etc/nvidia/kernel.conf
semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp
cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
dnf5 config-manager setopt fedora-multimedia.enabled=1
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
dnf5 config-manager setopt "terra-mesa".enabled=0
