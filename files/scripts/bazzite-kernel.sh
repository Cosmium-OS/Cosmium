#!/usr/bin/env bash
# based on https://github.com/askpng/solarpowered/blob/main/files/scripts/base/bazzite.sh

set -ouex pipefail

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

rm -drf /usr/lib/modules/*

GIT=https://github.com/bazzite-org/kernel-bazzite
GITOWNER=$(echo "$GIT" | sed -E 's#https://github.com/([^/]+)/([^/]+)(\.git)*#\1#')
GITREPO=$(echo "$GIT" | sed -E 's#https://github.com/([^/]+)/([^/]+)(\.git)*#\2#')

KERNEL_TAG=$(curl --fail --retry 5 --retry-delay 5 --retry-all-errors -s https://api.github.com/repos/$GITOWNER/$GITREPO/releases/latest | grep tag_name | cut -d : -f2 | tr -d 'v", ' | grep -Ev '\-[0-9]+\.[0-9]+$' | head -1)
KERNEL_VERSION=$KERNEL_TAG
OS_VERSION=$(rpm -E %fedora)

echo 'Installing Bazzite kernel.'
dnf5 install -y \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-core-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-modules-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-modules-core-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-modules-extra-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-modules-extra-matched-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-devel-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm \
    https://github.com/$GITOWNER/$GITREPO/releases/download/$KERNEL_TAG/kernel-devel-matched-$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64.rpm

echo 'Downloading ublue-os akmods COPR repo file'
curl --retry 5 -L https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-$(rpm -E %fedora)/ublue-os-akmods-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/_copr_ublue-os-akmods.repo

rm -rf /var/tmp
mkdir -p /var/tmp
chmod -R 1777 /var/tmp

# not really sure if we need this
echo 'Installing zenergy kmod'
dnf5 install -y \
    akmod-zenergy-*.fc$OS_VERSION.x86_64

akmods --force --kernels $KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64 --kmod zenergy
modinfo /usr/lib/modules/$KERNEL_VERSION.bazzite.fc$OS_VERSION.x86_64/extra/zenergy/zenergy.ko.xz > /dev/null \
    || (find /var/cache/akmods/zenergy/ -name \*.log -print -exec cat {} \; && exit 1)

echo 'Removing ublue-os akmods COPR repo file'
rm /etc/yum.repos.d/_copr_ublue-os-akmods.repo

echo 'Locking kernel version'
dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-tools kernel-tools-libs
