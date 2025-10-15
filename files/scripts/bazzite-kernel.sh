#!/usr/bin/env bash

set -oue pipefail

echo 'Removing existing kernel from the image.'
dnf5 remove -y --no-autoremove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-tools \
    kernel-tools-libs \
    kernel-uki-virt

echo 'Downloading kernel-cachyos-addons COPR repo file'
curl --retry 5 -L https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos-addons/repo/fedora-$(rpm -E %fedora)/bieszczaders-kernel-cachyos-addons-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/_copr_bieszczaders-kernel-cachyos-addons.repo

echo 'Installing scx-scheds pkg'
dnf5 install -y scx-scheds

echo 'Removing kernel-cachyos-addons COPR repo file'
rm /etc/yum.repos.d/_copr_bieszczaders-kernel-cachyos-addons.repo

echo 'Installing Bazzite kernel'
dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm \
    /tmp/kernel-rpms/kernel-tools-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-tools-libs-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-devel-*.rpm

echo 'Locking kernel version'
dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-tools kernel-tools-libs

echo 'Downloading akmods COPR repo files'
curl --retry 5 -L https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-$(rpm -E %fedora)/ublue-os-akmods-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/_copr_ublue-os-akmods.repo
curl --retry 5 -L https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/repo/fedora-$(rpm -E %fedora)/hikariknight-looking-glass-kvmfr-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo
curl --retry 5 -L https://copr.fedorainfracloud.org/coprs/rok/cdemu/repo/fedora-$(rpm -E %fedora)/rok-cdemu-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/_copr_rok-cdemu.repo

rm -rf /var/tmp
mkdir -p /var/tmp
chmod 1777 /var/tmp

echo 'Installing extra akmod RPMs'
dnf5 -y install \
    /tmp/akmods-rpms/kmods/*kvmfr*.rpm \
    /tmp/akmods-rpms/kmods/*xone*.rpm \
    /tmp/akmods-rpms/kmods/*openrazer*.rpm \
    /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
    /tmp/akmods-rpms/kmods/*wl*.rpm \
    /tmp/akmods-rpms/kmods/*framework-laptop*.rpm \
    /tmp/akmods-extra-rpms/kmods/*nct6687*.rpm \
    /tmp/akmods-extra-rpms/kmods/*gcadapter_oc*.rpm \
    /tmp/akmods-extra-rpms/kmods/*zenergy*.rpm \
    /tmp/akmods-extra-rpms/kmods/*vhba*.rpm \
    /tmp/akmods-extra-rpms/kmods/*gpd-fan*.rpm \
    /tmp/akmods-extra-rpms/kmods/*ayaneo-platform*.rpm \
    /tmp/akmods-extra-rpms/kmods/*ayn-platform*.rpm \
    /tmp/akmods-extra-rpms/kmods/*bmi260*.rpm \
    /tmp/akmods-extra-rpms/kmods/*ryzen-smu*.rpm

echo 'Removing akmods COPR repo files'
rm /etc/yum.repos.d/_copr_ublue-os-akmods.repo
rm /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo
rm /etc/yum.repos.d/_copr_rok-cdemu.repo
