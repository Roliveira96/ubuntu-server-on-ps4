#!/usr/bin/env bash
# Build an Ubuntu Server rootfs tarball (distro.tar.xz) for PS4 Linux.
# The PS4 kernel (bzImage) and initramfs are external, so the rootfs carries
# no kernel or bootloader. Run as root: sudo bash build-ubuntu-server.sh
set -euo pipefail

SUITE="${SUITE:-resolute}"            # Ubuntu 26.04 LTS
MIRROR="${MIRROR:-http://archive.ubuntu.com/ubuntu}"
HOSTNAME_NEW="${HOSTNAME_NEW:-ps4-server}"
USER_NAME="${USER_NAME:-${SUDO_USER:-ubuntu}}"
USER_PASS="${USER_PASS:-ps4ubuntu}"   # temporary, must be changed on first login
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/var/tmp/ps4-ubuntu-build}"
ROOT="${WORK}/rootfs"
OUT="${HERE}/ubuntu-26.04-server.tar.xz"
INITRAMFS="${HERE}/initramfs.cpio.gz"
SSH_KEY="${SSH_KEY:-$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/.ssh/id_ed25519.pub}"

[ "$(id -u)" -eq 0 ] || { echo "error: run as root (sudo)" >&2; exit 1; }

cleanup() {
    for m in dev/pts dev proc sys run; do
        mountpoint -q "${ROOT}/${m}" && umount -l "${ROOT}/${m}" || true
    done
}
trap cleanup EXIT

echo "==> Installing host tools"
command -v debootstrap >/dev/null || apt-get install -y debootstrap
command -v cpio >/dev/null || apt-get install -y cpio

echo "==> Bootstrapping ${SUITE} into ${ROOT}"
rm -rf "${WORK}"
mkdir -p "${ROOT}"
# Older debootstrap releases lack a script for new suites; Ubuntu suites all
# share the "gutsy" script, so fall back to it.
DBS_SCRIPT=""
[ -e "/usr/share/debootstrap/scripts/${SUITE}" ] || DBS_SCRIPT="/usr/share/debootstrap/scripts/gutsy"
debootstrap --arch=amd64 --components=main,universe \
    --include=systemd-sysv,locales,ca-certificates \
    "${SUITE}" "${ROOT}" "${MIRROR}" ${DBS_SCRIPT}

for m in dev dev/pts proc sys run; do
    mount --bind "/${m}" "${ROOT}/${m}"
done

echo "==> Writing base configuration"
cat > "${ROOT}/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: ${MIRROR}
Suites: ${SUITE} ${SUITE}-updates ${SUITE}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: ${SUITE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
: > "${ROOT}/etc/apt/sources.list"

# The kernel comes from the PS4 boot dir; never let apt install one.
cat > "${ROOT}/etc/apt/preferences.d/no-kernel" <<'EOF'
Package: linux-image-* linux-modules-* linux-generic* grub-* shim-signed
Pin: release *
Pin-Priority: -1
EOF

echo "${HOSTNAME_NEW}" > "${ROOT}/etc/hostname"
cat > "${ROOT}/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME_NEW}
::1 localhost ip6-localhost ip6-loopback
EOF

# The root image is mounted read-write by the initramfs, nothing to add here.
cat > "${ROOT}/etc/fstab" <<'EOF'
# Root is /data/home/linux.img on the PS4 HDD, mounted by the initramfs.
EOF

mkdir -p "${ROOT}/etc/netplan"
cat > "${ROOT}/etc/netplan/01-ethernet.yaml" <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    wired:
      match:
        name: "e*"
      dhcp4: true
      optional: true
EOF
chmod 600 "${ROOT}/etc/netplan/01-ethernet.yaml"

cat > "${ROOT}/etc/default/keyboard" <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="intl"
XKBOPTIONS=""
BACKSPACE="guess"
EOF

echo "==> Installing packages"
chroot "${ROOT}" /bin/bash -euo pipefail <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
sed -i 's/^# *\(pt_BR.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo America/Sao_Paulo > /etc/timezone

debconf-set-selections <<'SEL'
keyboard-configuration keyboard-configuration/modelcode string pc105
keyboard-configuration keyboard-configuration/layoutcode string us
keyboard-configuration keyboard-configuration/variantcode string intl
keyboard-configuration keyboard-configuration/xkb-keymap select us(intl)
SEL

apt-get update
apt-get -y full-upgrade
apt-get install -y --no-install-recommends \
    ubuntu-minimal ubuntu-standard \
    openssh-server sudo netplan.io systemd-resolved systemd-timesyncd \
    iproute2 iputils-ping net-tools dnsutils \
    wpasupplicant iw wireless-regdb \
    console-setup kbd keyboard-configuration \
    nano vim less bash-completion htop curl wget git \
    tmux ufw unattended-upgrades
apt-get -y autoremove --purge
apt-get clean
rm -rf /var/lib/apt/lists/*

systemctl enable ssh systemd-networkd systemd-resolved systemd-timesyncd
# No real network wait on boot when the cable is unplugged.
systemctl mask systemd-networkd-wait-online.service
CHROOT

# Re-assert the US international layout in case a package rewrote it.
cat > "${ROOT}/etc/default/keyboard" <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="intl"
XKBOPTIONS=""
BACKSPACE="guess"
EOF
grep -q '^XKBVARIANT="intl"' "${ROOT}/etc/default/keyboard"

echo "==> Creating user ${USER_NAME}"
chroot "${ROOT}" useradd -m -s /bin/bash -G sudo,adm "${USER_NAME}"
echo "${USER_NAME}:${USER_PASS}" | chroot "${ROOT}" chpasswd
chroot "${ROOT}" chage -d 0 "${USER_NAME}"
chroot "${ROOT}" passwd -l root

if [ -f "${SSH_KEY}" ]; then
    install -d -m 700 "${ROOT}/home/${USER_NAME}/.ssh"
    install -m 600 "${SSH_KEY}" "${ROOT}/home/${USER_NAME}/.ssh/authorized_keys"
    chroot "${ROOT}" chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/.ssh"
    echo "    authorized SSH key ${SSH_KEY}"
fi

echo "==> Copying PS4 GPU/Wi-Fi firmware from the initramfs"
FW_TMP="$(mktemp -d)"
(cd "${FW_TMP}" && zcat "${INITRAMFS}" | cpio -id --quiet 'lib/firmware/*')
cp -a "${FW_TMP}/lib/firmware/." "${ROOT}/usr/lib/firmware/"
rm -rf "${FW_TMP}"

echo "==> Final cleanup"
: > "${ROOT}/etc/machine-id"
rm -f "${ROOT}/var/lib/dbus/machine-id"
rm -f "${ROOT}"/etc/ssh/ssh_host_*
# Regenerate SSH host keys on first boot, unique per machine.
cat > "${ROOT}/etc/systemd/system/ssh-hostkeys.service" <<'EOF'
[Unit]
Description=Generate SSH host keys on first boot
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A

[Install]
WantedBy=multi-user.target
EOF
chroot "${ROOT}" systemctl enable ssh-hostkeys.service
rm -rf "${ROOT}"/tmp/* "${ROOT}"/var/tmp/* "${ROOT}"/var/log/*.log
cleanup

echo "==> Packing ${OUT}"
tar -C "${ROOT}" --numeric-owner -cf - . | xz -T0 -6 > "${OUT}"
chown "${SUDO_USER:-root}:" "${OUT}" 2>/dev/null || true
rm -rf "${WORK}"
ls -lh "${OUT}"
echo "Done."
