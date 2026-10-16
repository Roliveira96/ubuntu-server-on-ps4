#!/usr/bin/env bash
# Install Docker Engine + Compose plugin from Docker's official repository.
# Run with sudo.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
TARGET_USER="${SUDO_USER:-ricardo}"

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
cat > /etc/apt/sources.list.d/docker.sources <<SRC
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
SRC

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
usermod -aG docker "${TARGET_USER}"
systemctl enable --now docker containerd

docker run --rm hello-world | grep -m1 "Hello from Docker"
docker version --format 'Docker {{.Server.Version}}'
docker compose version
echo "User ${TARGET_USER} added to the docker group (re-login to apply)."
