#!/usr/bin/env bash
# One-shot build of everything needed to boot Ubuntu Server on a PS4:
#   1. download kernel, initramfs and loader payloads from upstream
#   2. verify them against SHA256SUMS
#   3. build the Ubuntu rootfs (distro.tar.xz) with build-ubuntu-server.sh
#   4. stage all files under out/ using the same paths as the PS4 filesystem
#   5. optionally upload out/ to the PS4 over FTP (PS4_IP=x.x.x.x)
#
# Usage: ./build.sh                     # build and stage only
#        PS4_IP=192.168.3.105 ./build.sh   # build, stage and upload
# Env:   SKIP_ROOTFS=1  reuse an existing ubuntu-26.04-server.tar.xz
#        PAYLOAD=linux-128mb.bin  loader payload (VRAM reserved for the GPU)
#        FTP_PORT=2121
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "${HERE}"

KERNEL_URL="https://gitlab.com/api/v4/projects/rmuxnet%2Flinux/packages/generic/Release-7%2E1%2E7-Aeolia-Belize/Release-7%2E1%2E7-Aeolia-Belize/7%2E1%2E7-Strawberry-Server-FullLTO%2Ezip"
INITRAMFS_URL="https://github.com/GayCorp/initramfs-ps4/releases/download/build-5096995/initramfs.cpio.gz"
# Upstream deletes old builds, so the pinned initramfs may be rebuilt from its
# source commit. Its firmware lives in a private repo and is taken from the
# rolling "latest" build instead. The result is checked by content hash
# (sha256 of the sorted per-file sha256 list), since cpio mtimes differ.
INITRAMFS_COMMIT="50969950ecd25f0d6bc24f20af95c3bf3a93ff24"
INITRAMFS_SRC_URL="https://github.com/GayCorp/initramfs-ps4/archive/${INITRAMFS_COMMIT}.tar.gz"
INITRAMFS_FW_URL="https://github.com/GayCorp/initramfs-ps4/releases/download/latest/initramfs.cpio.gz"
INITRAMFS_CONTENT_SHA256="c23e2d93dec5c449e490235b4e5020807eac0965e173b466fdd49d9c850a063c"
LOADER_URL="https://github.com/ps4-linux/ps4-linux-loader/releases/download/v25.1/ps4-linux-loader-v25.1.zip"
PAYLOAD="${PAYLOAD:-linux-128mb.bin}"
ROOTFS="ubuntu-26.04-server.tar.xz"
OUT="${HERE}/out"
FTP_PORT="${FTP_PORT:-2121}"

need() { command -v "$1" >/dev/null || { echo "error: missing '$1' (sudo apt install $2)" >&2; exit 1; }; }
need curl curl
need unzip unzip
need sha256sum coreutils
need cpio cpio

fetch() {
    local file="$1" url="$2"
    if [ -f "${file}" ] && grep -q " ${file}\$" SHA256SUMS \
        && sha256sum -c --status <(grep " ${file}\$" SHA256SUMS); then
        echo "    ${file}: already downloaded"
        return
    fi
    echo "    ${file}"
    curl -fL --progress-bar -o "${file}" "${url}"
}

content_sha256() {
    (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}

rebuild_initramfs() {
    echo "    pinned initramfs is gone upstream, rebuilding commit ${INITRAMFS_COMMIT:0:7}"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL "${INITRAMFS_SRC_URL}" | tar -xz -C "${tmp}"
    local src
    src="$(echo "${tmp}"/initramfs-ps4-*)"
    mkdir -p "${tmp}/fw" "${src}/lib/firmware"
    curl -fsSL "${INITRAMFS_FW_URL}" | (cd "${tmp}/fw" && zcat | cpio -idm --quiet 'lib/firmware/*')
    cp -a "${tmp}/fw/lib/firmware/amdgpu" "${tmp}/fw/lib/firmware/mrvl" "${src}/lib/firmware/"
    # PS4 Pro (gladius) firmware was added upstream after the pinned commit.
    rm -f "${src}"/lib/firmware/amdgpu/gladius_*
    # Same packing as upstream bake.sh, with the commit it would have recorded.
    chmod +x "${src}/init" "${src}"/bin/* "${src}"/hooks/*/* "${src}"/etc/profile.d/* 2>/dev/null || true
    echo "${INITRAMFS_COMMIT:0:7}" > "${src}/GIT_HASH"
    rm -f "${src}/bake.sh" "${src}/README.md" "${src}/.gitignore" "${src}/.gitattributes"
    rm -rf "${src}/.github"
    (cd "${src}" && find . -mindepth 1 -print0 | LC_ALL=C sort -z \
        | cpio --null -o -H newc -R 0:0 --quiet | gzip -9) > initramfs.cpio.gz
    local got
    got="$(content_sha256 "${src}")"
    rm -rf "${tmp}"
    if [ "${got}" != "${INITRAMFS_CONTENT_SHA256}" ]; then
        echo "error: rebuilt initramfs content differs from the tested one (${got})" >&2
        exit 1
    fi
    echo "    rebuilt initramfs matches the tested content"
}

echo "==> [1/5] Downloading boot files"
fetch kernel-server.zip "${KERNEL_URL}"
fetch payloads.zip "${LOADER_URL}"
if ! sha256sum -c --status <(grep ' initramfs.cpio.gz$' SHA256SUMS) 2>/dev/null; then
    curl -fsSL -o initramfs.cpio.gz "${INITRAMFS_URL}" 2>/dev/null \
        && sha256sum -c --status <(grep ' initramfs.cpio.gz$' SHA256SUMS) \
        && echo "    initramfs.cpio.gz" \
        || rebuild_initramfs
else
    echo "    initramfs.cpio.gz: already downloaded"
fi

echo "==> [2/5] Verifying checksums"
sha256sum -c <(grep -v ' initramfs.cpio.gz$' SHA256SUMS)

rm -rf kernel payloads
unzip -o -q kernel-server.zip -d kernel
unzip -o -q payloads.zip -d payloads
PAYLOAD_PATH="$(find payloads -path '*/bin/*' -name "${PAYLOAD}" | head -1)"
[ -n "${PAYLOAD_PATH}" ] || { echo "error: payload ${PAYLOAD} not found in payloads.zip" >&2; exit 1; }

echo "==> [3/5] Building the Ubuntu rootfs"
if [ "${SKIP_ROOTFS:-0}" = "1" ] && [ -f "${ROOTFS}" ]; then
    echo "    reusing ${ROOTFS}"
else
    sudo --preserve-env=SUITE,MIRROR,HOSTNAME_NEW,USER_NAME,USER_PASS,SSH_KEY \
        bash "${HERE}/build-ubuntu-server.sh"
fi

echo "==> [4/5] Staging files under out/ (PS4 filesystem layout)"
rm -rf "${OUT}"
install -D -m 644 kernel/bzImage        "${OUT}/data/linux/boot/bzImage"
install -D -m 644 initramfs.cpio.gz     "${OUT}/data/linux/boot/initramfs.cpio.gz"
install -D -m 644 "${ROOTFS}"           "${OUT}/user/system/boot/distro.tar.xz"
install -D -m 644 "${PAYLOAD_PATH}"     "${OUT}/data/GoldHEN/payloads/${PAYLOAD}"
(cd "${OUT}" && find . -type f -printf '%P\n' | sort | xargs sha256sum > "${HERE}/out.sha256")
mv "${HERE}/out.sha256" "${OUT}/SHA256SUMS"
(cd "${OUT}" && find . -type f -exec ls -lh {} + | awk '{print "    " $5 "\t" $9}')

echo "==> [5/5] Upload"
if [ -z "${PS4_IP:-}" ]; then
    echo "    skipped (set PS4_IP to upload over FTP, see README.md)"
    echo "Done. Files are ready in ${OUT}"
    exit 0
fi
FTP="ftp://${PS4_IP}:${FTP_PORT}"
curl -s --max-time 10 "${FTP}/" >/dev/null \
    || { echo "error: no FTP server at ${FTP} (is GoldHEN FTP running?)" >&2; exit 1; }
failed=0
while read -r sum path; do
    echo "    /${path}"
    curl -fsS --ftp-create-dirs -T "${OUT}/${path}" "${FTP}/${path}"
    remote_sum="$(curl -fsS "${FTP}/${path}" | sha256sum | cut -d' ' -f1)"
    if [ "${remote_sum}" = "${sum}" ]; then
        echo "      checksum OK"
    else
        echo "      CHECKSUM MISMATCH" >&2
        failed=1
    fi
done < "${OUT}/SHA256SUMS"
[ "${failed}" -eq 0 ] || { echo "error: some uploads differ, run again" >&2; exit 1; }
echo "Done. Load ${PAYLOAD} from GoldHEN and follow README.md step 5."
