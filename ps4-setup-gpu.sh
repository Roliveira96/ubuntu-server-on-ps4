#!/usr/bin/env bash
# Enable GPU acceleration (OpenGL via radeonsi, Vulkan via RADV) for a user.
# The amdgpu driver and the liverpool firmware already come with the kernel
# and the rootfs; this only installs the userspace bits and the groups.
# Run with sudo. The user must log out and back in afterwards.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
TARGET_USER="${SUDO_USER:-ricardo}"

apt-get update
apt-get install -y mesa-vulkan-drivers mesa-utils vulkan-tools
usermod -aG video,render "${TARGET_USER}"

echo "==> Kernel side"
grep -qw 'amdgpu.dpm=0' /proc/cmdline \
    && echo "    amdgpu.dpm=0 present (keep it: DPM hangs the PS4)" \
    || echo "    WARNING: amdgpu.dpm=0 missing from the kernel command line"
ls /dev/dri

echo "==> OpenGL (expect radeonsi, kaveri)"
eglinfo -B 2>/dev/null | grep -m2 -iE 'renderer|core profile version' || true
echo "==> Vulkan (expect GPU 0: RADV KAVERI)"
# 'vulkaninfo --summary' fails with ERROR_OUT_OF_HOST_MEMORY when headless; this works.
MESA_VK_DEVICE_SELECT=list vulkaninfo 2>/dev/null | grep -E 'GPU [0-9]' || true
echo "User ${TARGET_USER} added to video and render (re-login to apply)."
