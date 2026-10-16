#!/usr/bin/env bash
# Pin the PS4 Wi-Fi to a static IP and rename the host. Run with sudo.
set -euo pipefail

NEW_HOSTNAME="ubuntu"
IFACE="mlan0"
ADDRESS="192.168.3.105/24"
GATEWAY="192.168.3.1"

hostnamectl set-hostname "${NEW_HOSTNAME}"
sed -i "s/^127\.0\.1\.1 .*/127.0.1.1 ${NEW_HOSTNAME}/" /etc/hosts
echo "hostname: $(hostname)"

# Merged on top of 02-wifi.yaml, which keeps the SSID and password.
cat > /etc/netplan/03-static-ip.yaml <<NETPLAN
network:
  version: 2
  wifis:
    ${IFACE}:
      dhcp4: false
      addresses: [${ADDRESS}]
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${GATEWAY}, 1.1.1.1]
NETPLAN
chmod 600 /etc/netplan/03-static-ip.yaml

netplan generate
echo "netplan config is valid, applying..."
nohup netplan apply >/dev/null 2>&1 &
sleep 8
ip -4 -br addr show "${IFACE}"
ip route | grep default
