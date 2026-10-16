#!/usr/bin/env bash
# Install a minimal XFCE desktop started on demand (boot stays text-only),
# plus Firefox from Mozilla's APT repository. Run with sudo.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Adding Mozilla APT repository (Firefox as .deb, no snap)"
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc
cat > /etc/apt/sources.list.d/mozilla.sources <<'SRC'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
SRC
cat > /etc/apt/preferences.d/mozilla <<'PIN'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
PIN

echo "==> Installing XFCE, Xorg and LightDM"
apt-get update
apt-get install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg-video-amdgpu xserver-xorg-input-libinput \
    x11-xserver-utils xinit dbus-x11 libgl1-mesa-dri libglx-mesa0 \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 xfce4-settings xfconf \
    xfce4-terminal thunar xfce4-notifyd xfce4-whiskermenu-plugin \
    lightdm lightdm-gtk-greeter \
    adwaita-icon-theme elementary-xfce-icon-theme fonts-dejavu-core \
    policykit-1-gnome gvfs \
    firefox firefox-l10n-pt-br

echo "==> Keeping boot in text mode (desktop only on demand)"
systemctl disable lightdm.service 2>/dev/null || true
rm -f /etc/systemd/system/display-manager.service
systemctl set-default multi-user.target

# Helper commands: 'desktop' starts the GUI on the TV, 'desktop-off' stops it.
cat > /usr/local/bin/desktop <<'CMD'
#!/bin/sh
exec sudo systemctl start lightdm
CMD
cat > /usr/local/bin/desktop-off <<'CMD'
#!/bin/sh
exec sudo systemctl stop lightdm
CMD
chmod 755 /usr/local/bin/desktop /usr/local/bin/desktop-off

apt-get clean
echo "==> Done. Default target: $(systemctl get-default)"
df -h / | tail -1
