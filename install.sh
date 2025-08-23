#!/usr/bin/bash
set -euo pipefail

error() {
    echo ERROR: "$@"
    exit 1
}

exec_with_status() {
    set +e
    "$@"
    status=$?
    set -e
}

download() {
    echo Downloading "$1"
    curl -fL "$DOWNLOAD_BASE/$1" -o "$1"
    echo
}

mkdir_if_needed() {
    if [[ ! -d "$1" ]]; then mkdir "$1"; fi
}

if [[ $UID != 0 ]]; then
    error This script must be run as root!
fi

SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
WORKING_DIRECTORY="$SCRIPT_DIR/installer-data"
ROOTFS_EXTRACT_DIRECTORY="$WORKING_DIRECTORY/container-rootfs"
VM_INSTALL_DIR="/mnt/internal/linux"
DOWNLOAD_BASE="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Container/aarch64/images"
#DOWNLOAD_BASE="http://10.0.2.2:8000"
CONTAINER_IMAGE="Fedora-Container-Base-Generic-42-1.1.aarch64.oci.tar.xz"
CHECKSUM_FILE="Fedora-Container-42-1.1-aarch64-CHECKSUM"
ROOTFS_BLOB_HASH="cfc0be9fb5518ec8eb4521cdb4dc2ee14df42924e0f468d24a8e6cfbdda5fdc9"
# directories need a . at the end for cp to copy the contents instead of the directory itself
PRESERVED_PATHS=(
    /etc/fstab
    /etc/systemd/system/avahi_ttyd.service
    /etc/systemd/system/backup_mount.service
    /etc/systemd/system/ttyd.service
    /etc/systemd/system/virtiofs.service
    /etc/systemd/system/virtiofs_internal.service
    /etc/ttyd/.
    /usr/bin/forwarder_guest
    /usr/bin/forwarder_guest_launcher
    /usr/bin/shutdown_runner
    /usr/bin/storage_balloon_agent
    /usr/lib/systemd/system/forwarder-guest-launcher.service
    /usr/lib/systemd/system/shutdown-runner.service
    /usr/lib/systemd/system/storage-balloon-agent.service
    /usr/local/bin/.
    /usr/sbin/tcpstates-bpfcc # couldn't find a fedora package providing this
)

FEDORA_42_KEY=\
"mQINBGXKg9EBEACvsAjRcllcH6mVReU/0hi5YnwqulP7gNgUM4jYPiqucF51g0oWMbFk0VjDn3QX
jrwLNLtj4oxsU+E6OW0jl1732qvjUJ9geEZBuidyFZgq0CCn9K8d661dPDjN/DzWWogFhnDySFHR
Ldh6dYCuu75/HKSIVfCud2IFCvT7Bhk4AOpxv4c7mmX874LFgi49jkAYC0M6UbJ9o3KSCndipf/k
0ra2g9dGacqlPfn3PMiTszPDr99do4qZ5dVZYC6Sna8GjNhN7b/2xLGQuzdd9LHgPHC/PX7XsvBL
u42rqi3q0umJBtjZCyFxF5Dp0VMwmVfrKFZOHvVsGjPLrxomLU16/EDzIrw6cHikdQKLf4sl0rX0
m8j0PNAGOSDmE9YgByiPo12CGMOuAvsDUI0JID4p4WqpBShTBuiIrITn8XVTCOQ+tKq9dE/qI+mm
2hnZjJajM2UWfKE0mVH4SDOiSilgKR/h5HuLZqwtYXFExDZsAcxaLfRBKCrIOyJdpV7YIj8PaP89
XeycHM2MaIfwdHSx3Pz39zZNzi6vJkLj9SWdQT7lOvZxxTQ3dK0Rcpjx+rGHgihMT4yBd+JO9mZS
3ghNGbypYnNn/mohPOAxguXuPuPRj00oC7C3lIEEL/hZXZbN1SuiopZjxbU/x/5lO8n0Un1GCzyn
ObPDvpDLTjsdKQARAQABtDFGZWRvcmEgKDQyKSA8ZmVkb3JhLTQyLXByaW1hcnlAZmVkb3JhcHJv
amVjdC5vcmc+iQJOBBMBCAA4FiEEsPSVBFj2nhFQxsXtyKxJFhBe+UQFAmXKg9ECGw8FCwkIBwIG
FQoJCAsCBBYCAwECHgECF4AACgkQyKxJFhBe+US4mQ//e4gIGhA6TJuEqrVPgKtSnDawIj30TGbk
XIywECtKCu9N8anTlkU2/XSKGyE3ZDdKDO77O11382Ci1xJgCpdbqKg4G02ecEKT1Dtng37gt55S
khffQ0EeDb3Zl+Pu5qohHQUiMzio4B4q8n0HD+L9klQ3I1rLmymguBRd34jQH/z025GE2SBbCpDn
QCChZT7Fq1D/onOQgC6skN6QE2dvYqOnSlHkkfuVlRRYoLNmynxHKlL6VZkiM7m1zKi7cMEK63mK
JQ3jH3Mc9grh+OwBDxOjx5UoYMeYqq7oXyTPKvvf6ssuHtjWM3tNkyi5R1nB+4SHMttrbt2pLMSH
Jg6pNXoLAP8ahlvxdgVRjgN/6OMC/DwXnLxippelBXXDyBnwVd8/WohbJDcq7e5tdymZpRsNxzhW
SuwbHzeJY1DKtePhbjblShLjxTzLnS4GBPJV5TXpHkZWgQmz2aA0CHV47j37P6kAOEtsJkJUWWz+
/Rx1N5Mm5lxvghaAzlTBtwQhRgl9Y8kCTznG40QQ64N2FOrcExUJmujLRISDjM2Ps9MtBlbYs7H4
JDziX4jpNyvhVAbEdjbzVfL5oi35l+K/QRtQJnt78qhLpNNB7SdQkNmD8eMeXF7mA/MH6eFM88hF
4l6NeKklyMIa5thgLFx0UyEgoLXDBg+thUzby61gnA8="

stage1() {
    echo "********************************************"
    echo "*                 WARNING!                 *"
    echo "*                                          *"
    echo "* This script will replace your Debian     *"
    echo "* install with Fedora. Please take backups *"
    echo "* of any important files stored in the     *"
    echo "* terminal, as they WILL BE erased and the *"
    echo "* system may stop working at any time.     *"
    echo "********************************************"
    read -p "Do you wish to continue? [y/N] " -r answer
    if [[ ! $answer =~ [yY] ]]; then
        echo Installation interrupted
        exit
    fi

    apt update
    apt install -y jq

    cd "$WORKING_DIRECTORY"

    # Download and verify a fedora container image
    download "$CONTAINER_IMAGE"
    download "$CHECKSUM_FILE"

    base64 -d <<< "$FEDORA_42_KEY" > fedora42.keyring
    exec_with_status gpgv --keyring ./fedora42.keyring "$CHECKSUM_FILE"

    if [[ $status != 0 ]]; then
        error Image signature verification failed
    fi

    image_checksum=$(grep "$CONTAINER_IMAGE" "$CHECKSUM_FILE")
    exec_with_status sha256sum -c --quiet <<< "$image_checksum"

    if [[ $status != 0 ]]; then
        error Image checksum verification failed
    fi

    echo Extracting fedora rootfs...
    tar xJf "$CONTAINER_IMAGE" "blobs/sha256/$ROOTFS_BLOB_HASH" -O > rootfs.tar.gz
    rm "$CONTAINER_IMAGE"

    if [[ -d "$ROOTFS_EXTRACT_DIRECTORY" ]]; then rm -rf "$ROOTFS_EXTRACT_DIRECTORY"; fi
    mkdir "$ROOTFS_EXTRACT_DIRECTORY"
    cd "$ROOTFS_EXTRACT_DIRECTORY"
    tar xzf "$WORKING_DIRECTORY/rootfs.tar.gz"
    cd "$WORKING_DIRECTORY"

    echo Creating a fedora partition...
    fallocate -l 2G "$VM_INSTALL_DIR/fedora_root_part"
    jq '.disks+=[{
        "partitions": [
            {
                "label": "FEDORA_ROOT",
                "path": "$PAYLOAD_DIR/fedora_root_part",
                "writable": true
            }
        ],
        "writable": true
    }]' "$VM_INSTALL_DIR/vm_config.json" > vm_config_new.json
    cp vm_config_new.json "$VM_INSTALL_DIR/vm_config.json"

    echo "NEXT_STAGE=2" > installer.state

    echo
    echo Partition created. Please restart the terminal to make it visible to the system and re-run the script to continue installation.
}

stage2() {
    echo Formatting the fedora partition...
    FEDORA_PART_DEVICE=$(realpath /dev/disk/by-partlabel/FEDORA_ROOT)
    mkfs.ext4 "$FEDORA_PART_DEVICE"
    mkdir -p "$ROOTFS_EXTRACT_DIRECTORY/mnt/install"
    mount "$FEDORA_PART_DEVICE" "$ROOTFS_EXTRACT_DIRECTORY/mnt/install"

    # Prepare a chroot environment
    mount --bind /dev "$ROOTFS_EXTRACT_DIRECTORY/dev"
    mount --bind /sys "$ROOTFS_EXTRACT_DIRECTORY/sys"
    mount --bind /proc "$ROOTFS_EXTRACT_DIRECTORY/proc"
    cp /etc/resolv.conf "$ROOTFS_EXTRACT_DIRECTORY/etc/resolv.conf"
    cp "$SCRIPT_PATH" "$ROOTFS_EXTRACT_DIRECTORY/tmp/install.sh"

    chroot "$ROOTFS_EXTRACT_DIRECTORY" /tmp/install.sh 3

    echo Copying files from debian image...
    for path in "${PRESERVED_PATHS[@]}"; do
        parent=$(dirname "$path")
        mkdir -p "$ROOTFS_EXTRACT_DIRECTORY/mnt/install/$parent"
        cp -a "$path" "$ROOTFS_EXTRACT_DIRECTORY/mnt/install/$path"
    done

    mount -t tmpfs tmpfs "$ROOTFS_EXTRACT_DIRECTORY/mnt/install/tmp"
    cp "$SCRIPT_PATH" "$ROOTFS_EXTRACT_DIRECTORY/mnt/install/tmp/install.sh"
    chroot "$ROOTFS_EXTRACT_DIRECTORY/mnt/install" "/tmp/install.sh" 4

    echo Syncing filesystems...
    sync
    echo Unmounting fedora partition...
    umount -R "$ROOTFS_EXTRACT_DIRECTORY/mnt/install"

    cd "$WORKING_DIRECTORY"
    jq '.disks=.disks[:-1]' "$VM_INSTALL_DIR/vm_config.json" > vm_config_new.json
    cp vm_config_new.json "$VM_INSTALL_DIR/vm_config.json"
    mv "$VM_INSTALL_DIR/fedora_root_part" "$VM_INSTALL_DIR/root_part"

    echo
    echo Installation complete! Restart the terminal to boot into Fedora.
}

stage3() {
    sed -i -e '/tsflags=nodocs/d' /etc/dnf/dnf.conf
    
    # systemd was complaining about missing proc
    mkdir /mnt/install/dev /mnt/install/sys /mnt/install/proc
    mount --bind /dev /mnt/install/dev
    mount --bind /sys /mnt/install/sys
    mount --bind /proc /mnt/install/proc

    echo Installing system...
    dnf group install --installroot=/mnt/install --use-host-config --assumeyes --exclude=dhcp-client,openssh-server,parted,NetworkManager,dracut-config-rescue,fwupd,plymouth core
    dnf install --installroot=/mnt/install --use-host-config --assumeyes avahi avahi-tools glibc-all-langpacks libdnf5-plugin-actions bcc \
        acl attr bash-color-prompt bzip2 chrony file gnupg2 lsof man-pages pciutils systemd-oomd-defaults tree tar unzip usbutils which zip

    cd /mnt/install

    mkdir_if_needed etc/systemd/system-preset
    cat > etc/systemd/system-preset/50-avf.preset <<EOF
enable systemd-networkd.service

# we use systemd-networkd
disable NetworkManager.service
disable NetworkManager-wait-online.service
disable NetworkManager-dispatcher.service

# not very useful in a vm and would probably conflict with port forwarding
disable firewalld.service

# android terminal dependencies
enable avahi_ttyd.service
enable backup_mount.service
enable forwarder-guest-launcher.service
enable shutdown-runner.service
enable storage-balloon-agent.service
enable ttyd.service
enable virtiofs.service
enable virtiofs_internal.service
EOF

    # the initramfs resolves the immediate destination of /sbin/init resulting in /newroot/../lib/systemd/systemd
    echo "post_transaction:systemd:in::/usr/bin/ln -sf /lib/systemd/systemd /sbin/init" > etc/dnf/libdnf5-plugins/actions.d/initramfs.actions
}

stage4() {
    # use dhcp on all ethernet network interfaces
    ln -s /usr/lib/systemd/network/89-ethernet.network.example /etc/systemd/network/89-ethernet.network
    # disable LLMNR globally
    cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
LLMNR=no
EOF
    # upstream resolv.conf mode is used by the default debian image
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    # debian image defaults to UTC
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    # debian image defaults to en_US.UTF-8
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    # debian image doesn't have an explicit hostname set but defaults to localhost
    echo "localhost" > /etc/hostname

    # fix symlink after first install of systemd
    ln -sf /lib/systemd/systemd /sbin/init

    adduser -g users -G wheel droid
    echo "droid ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

    # enable autologin as in the debian image
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-f -- \\\\u' --noreset --noclear - \${TERM}
EOF
    mkdir -p /etc/systemd/system/serial-getty@.service.d
    cat > /etc/systemd/system/serial-getty@.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-f -- \\\\u' --noreset --noclear --keep-baud 115200,57600,38400,9600 - \${TERM}
EOF

    # login now takes over the terminal and calls vhangup, so cannot be used with ttyd
    sed -i -e 's/login -f droid/su -l droid\nSELinuxContext=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023/' /etc/systemd/system/ttyd.service

    # these services were unnecessarily started via bash, resulting in them running in initrc_t domain instead of unconfined_service_t
    sed -i -Ee "s/\/usr\/bin\/bash -c '(.+)'/\1/" /usr/lib/systemd/system/forwarder-guest-launcher.service
    sed -i -Ee "s/\/usr\/bin\/bash -c '(.+)'/\1/" /usr/lib/systemd/system/shutdown-runner.service
    sed -i -Ee "s/\/usr\/bin\/bash -c '(.+)'/\1/" /usr/lib/systemd/system/storage-balloon-agent.service

    # dont enable SELinux enforcement yet
    sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

    systemctl preset-all
}

mkdir_if_needed "$WORKING_DIRECTORY"
if [[ -f "$WORKING_DIRECTORY/installer.state" ]]; then
    # state file is written by the script itself and cannot be checked here
    # shellcheck disable=SC1091
    . "$WORKING_DIRECTORY/installer.state"
fi

: "${NEXT_STAGE:=1}"
stage=${1:-$NEXT_STAGE}

echo Starting stage "$stage"
case $stage in
    1)
        stage1
        ;;
    2)
        stage2
        ;;
    3)
        stage3
        ;;
    4)
        stage4
        ;;
    *)
        error Invalid stage "$stage"
        ;;
esac

