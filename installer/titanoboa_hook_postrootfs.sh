#!/usr/bin/env bash

set -exo pipefail

source /etc/os-release

# Install Anaconda webui
dnf install -qy anaconda-live libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state # Needed for Anaconda Web UI
# TODO: Enable Anaconda Web UI whenever locale switching in kde lands
# dnf install -qy anaconda-webui

# Utilities for displaying a dialog prompting users to review secure boot documentation
dnf install -qy --setopt=install_weak_deps=0 qrencode yad

# Variables
imageref="$(podman images --format '{{ index .Names 0 }}\n' 'cosmium*' | head -1)"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"
imagetag="$(podman images --format '{{ .Tag }}\n' "$imageref" | head -1)"

# Cosmium anaconda profile
: ${VARIANT_ID:?}
cat >/etc/anaconda/profile.d/cosmium.conf <<EOF
# Anaconda configuration file for Cosmium

[Profile]
# Define the profile.
profile_id = cosmium

[Profile Detection]
# Match os-release values
os_id = cosmium

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
#custom_stylesheet = /usr/share/anaconda/pixmaps/fedora.css
hidden_spokes =
    NetworkSpoke
    PasswordSpoke

hidden_webui_pages =
    root-password
    network

[Localization]
use_geolocation = False
EOF

echo "Cosmium release $VERSION_ID ($VERSION_CODENAME)" >/etc/system-release

# Get Artwork
#git clone --depth 1 --quiet https://github.com/Cosmium-OS/Cosmium.git /root/packages
#case "${PRETTY_NAME,,}" in
#"#cosmium"*)
#    mkdir -p /usr/share/anaconda/pixmaps/silverblue
#    cp -r /root/packages/installer/branding/* /usr/share/anaconda/pixmaps/
#    ;;
#esac
#rm -rf /root/packages

# Secureboot Key Fetch
#mkdir -p /usr/share/ublue-os
#curl -Lo /usr/share/ublue-os/sb_pubkey.der "$sbkey"

# Default Kickstart
cat <<EOF >>/usr/share/anaconda/interactive-defaults.ks

# Create log directory
%pre
mkdir -p /tmp/anacoda_custom_logs
%end

# Check if there is a bitlocker partition and ask the user to disable it
%pre --erroronfail --log=/tmp/anacoda_custom_logs/detect_bitlocker.log
DOCS_QR=/tmp/detect_bitlocker_qr.png
IS_BITLOCKER=\$(lsblk -o FSTYPE --json | jq '.blockdevices | map(select(.fstype == "BitLocker")) | . != []')
if [[ \$IS_BITLOCKER =~ true ]]; then
    qrencode -o \$DOCS_QR "https://www.wikihow.com/Turn-Off-BitLocker"
    run0 --user=liveuser yad --timeout=0 --image=\$DOCS_QR \
        --text="<b>Windows Bitlocker partition detected</b>\nPlease, disable it in Windows or delete it in GNOME Disks\nor disconnect its storage drive." || :
    exit 1
fi
%end

# Remove the efi dir, must match efi_dir from the profile config
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# Relabel the boot partition for the
%pre-install --erroronfail --log=/tmp/anacoda_custom_logs/repartitioning.log
set -x
xboot_dev=\$(findmnt -o SOURCE --nofsroot --noheadings -f --target /mnt/sysroot/boot)
if [[ -z \$xboot_dev ]]; then
  echo "ERROR: xboot_dev not found"
  exit 1
fi
e2label "\$xboot_dev" "cosmium_xboot"
%end

# Open a dialog with the installation logs
%onerror
run0 --user=liveuser yad \
    --timeout=0 \
    --text-info \
    --no-buttons \
    --width=600 \
    --height=400 \
    --text="An error occurred during installation. Please report this issue to the developers." \
    < /tmp/anaconda.log
%end

$(
    if [[ $imageref == *-deck* ]]; then
        cat <<EOCAT
# Set default user
user --name=cosmium --password=cosmium --plaintext --groups=wheel
EOCAT
    fi
)

ostreecontainer --url=$imageref:$imagetag --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
#%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
#%include /usr/share/anaconda/post-scripts/secureboot-docs.ks

EOF

# Signed Images
cat <<EOF >>/usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%post --erroronfail --log=/tmp/anacoda_custom_logs/bootc-switch.log
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry $imageref:$imagetag
%end
EOF

# Enroll Secureboot Key
#cat <<EOF >>/usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
#%post --erroronfail --nochroot --log=/tmp/anacoda_custom_logs/secureboot-enroll-key.log
#set -oue pipefail

#readonly ENROLLMENT_PASSWORD="universalblue"
#readonly SECUREBOOT_KEY="$SECUREBOOT_KEY"

#if [[ ! -d "/sys/firmware/efi" ]]; then
#	echo "EFI mode not detected. Skipping key enrollment."
#	exit 0
#fi

#if [[ ! -f "\$SECUREBOOT_KEY" ]]; then
#	echo "Secure boot key not provided: \$SECUREBOOT_KEY"
#	exit 0
#fi

#SYS_ID="\$(cat /sys/devices/virtual/dmi/id/product_name)"
#if [[ ":Jupiter:Galileo:" =~ ":\$SYS_ID:" ]]; then
#	echo "Steam Deck hardware detected. Skipping key enrollment."
#	exit 0
#fi

#mokutil --timeout -1 || :
#echo -e "\$ENROLLMENT_PASSWORD\n\$ENROLLMENT_PASSWORD" | mokutil --import "\$SECUREBOOT_KEY" || :
#%end
#EOF

#cat <<EOF >>/usr/share/anaconda/post-scripts/secureboot-docs.ks
#%post --nochroot --log=/tmp/anacoda_custom_logs/secureboot-docs.log
#SECUREBOOT_KEY="$SECUREBOOT_KEY"
#SECUREBOOT_DOC_URL="$SECUREBOOT_DOC_URL"
#SECUREBOOT_DOC_URL_QR="$SECUREBOOT_DOC_URL_QR"

#LC_ALL=C mokutil -t "\$SECUREBOOT_KEY" | grep -q "is already in the enrollment request" && \
#    run0 --user=liveuser yad --timeout=0 --on-top --button=Ok:0 --image="\$SECUREBOOT_DOC_URL_QR" --text="<b>Secure Boot Key added:</b>\nPlease check the documentation to finish enrolling the key\n\$SECUREBOOT_DOC_URL"
#%end
#EOF

#qrencode -o "$SECUREBOOT_DOC_URL_QR" "$SECUREBOOT_DOC_URL"

# Install Flatpaks
cat <<'EOF' >>/usr/share/anaconda/post-scripts/install-flatpaks.ks
%post --erroronfail --nochroot --log=/tmp/anacoda_custom_logs/install-flatpaks.log
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP /var/lib/flatpak "$target"
%end
EOF

# Disable Fedora Flatpak Repo
cat <<EOF >>/usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%post --erroronfail --log=/tmp/anacoda_custom_logs/disable-fedora-flatpak.log
systemctl disable flatpak-add-fedora-repos.service || :
%end
EOF

# Set Anaconda Payload to use flathub
cat <<EOF >>/etc/anaconda/conf.d/anaconda.conf
[Payload]
flatpak_remote = flathub https://dl.flathub.org/repo/
EOF

### Livecds runtime tweaks ###

# Disable services
(
    set +e
    for s in \
        rpm-ostree-countme.service \
        tailscaled.service \
        bootloader-update.service \
        brew-upgrade.timer \
        brew-update.timer \
        brew-setup.service \
        rpm-ostreed-automatic.timer \
        uupd.timer \
        ublue-guest-user.service \
        ublue-os-media-automount.service \
        ublue-system-setup.service; do
        systemctl disable $s
    done

    for s in \
        ublue-flatpak-manager.service \
        podman-auto-update.timer \
        ublue-user-setup.service; do
        systemctl --global disable $s
    done
)

### Desktop-enviroment specific tweaks ###

# Determine desktop environment. Must match one of /usr/libexec/livesys/sessions.d/livesys-{desktop_env}
# See https://github.com/ublue-os/titanoboa/blob/6c2e8ba58c7534b502081fe24363d2a60e7edca9/Justfile#L199-L213
desktop_env=""
_session_file="$(find /usr/share/wayland-sessions/ /usr/share/xsessions \
    -maxdepth 1 -type f -not -name '*gamescope*.desktop' -and -name '*.desktop' -printf '%P' -quit)"
case $_session_file in
budgie*) desktop_env=budgie ;;
cosmic*) desktop_env=cosmic ;;
gnome*) desktop_env=gnome ;;
plasma*) desktop_env=kde ;;
sway*) desktop_env=sway ;;
xfce*) desktop_env=xfce ;;
esac

# Don't start Steam at login
rm -vf /etc/skel/.config/autostart/steam*.desktop

# Remove packages that shouldnt be used in a live session
dnf -yq remove steam lutris || :

# Enable on-screen keyboard
#if [[ $imageref == *-deck* ]]; then
#    # Enable keyboard here
#    if [[ $desktop_env == gnome ]]; then
#        echo >>/etc/skel/.bash_profile \
#            "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true >/dev/null 2>&1 || :"
#        rm -rf /usr/share/gnome-shell/extensions/block-caribou-36@lxylxy123456.ercli.dev
#    elif [[ $desktop_env == kde ]]; then
#        mv /usr/share/ublue-os/backup/com.github.maliit.keyboard.desktop \
#            /usr/share/applications/com.github.maliit.keyboard.desktop || :
#    fi
#fi

# Let only browser/installer in the task-bar/dock
#if [[ $desktop_env == kde ]]; then
#    sed -i '/<entry name="launchers" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>preferred:\/\/browser,applications:liveinst.desktop,preferred:\/\/filemanager<\/default>/' \
#        /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml
#elif [[ $desktop_env == gnome ]]; then
#    cat >/usr/share/glib-2.0/schemas/zz2-org.gnome.shell.gschema.override <<EOF
#[org.gnome.shell]
#welcome-dialog-last-shown-version='4294967295'
#favorite-apps = ['liveinst.desktop', 'org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop']
#EOF
#    glib-compile-schemas /usr/share/glib-2.0/schemas
#fi

# Add support for controllers
_tmp=$(mktemp -d)
(
    set -eo pipefail
    dnf -yq install python-evdev python-rich
    git clone https://github.com/hhd-dev/jkbd "$_tmp"
    cd "$_tmp"
    python -m venv .venv
    #shellcheck disable=1091
    source .venv/bin/activate
    pip install build installer setuptools wheel
    python -m build --wheel --no-isolation
    python -m installer --prefix=/usr --destdir=/ dist/*.whl
    sed -i '1s|.*|#!/usr/bin/python|' /usr/bin/jkbd
    mkdir -p /usr/lib/systemd/system/
    install -m644 usr/lib/systemd/system/jkbd.service /usr/lib/systemd/system/jkbd.service
    systemctl enable jkbd.service
) || :
rm -rf "$_tmp"
unset -v _tmp

# Install Gparted
dnf -yq install gparted

###############################
