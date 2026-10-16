#!/usr/bin/env bash
# Migrate Docker data from this notebook to the PS4 server:
#   1. logical dumps of the running databases (extra safety copy)
#   2. named volumes copied with the same names and compose labels
#   3. per-volume checksum comparison between both hosts
# Containers that use a volume are stopped during its copy and restarted after.
set -euo pipefail

REMOTE="${REMOTE:-ricardo@192.168.3.105}"
DUMP_DIR="/home/ricardo/migration/dumps"
HELPER="alpine:3"
VOLUMES=(
    agrolink_dbdata
    camping-backend_minio_data
    camping-backend_nats_data
    camping-backend_postgres_data
    linux-lab_mailpit-data
    linux-lab_minio-data
    linux-lab_postgres-data
    studio4you-wordpress_dbdata
)

remote() { ssh -o BatchMode=yes "${REMOTE}" "$@"; }

# Checksum of every file in a volume, independent of host and file order.
CHECKSUM_CMD='cd /v && find . -type f -print0 | sort -z | xargs -0 -r md5sum | md5sum | cut -d" " -f1'

echo "==> Preparing helper image on both hosts"
docker pull -q "${HELPER}" >/dev/null
remote "docker pull -q ${HELPER} >/dev/null && mkdir -p ${DUMP_DIR}"

echo "==> Logical database dumps"
dump() {
    local name="$1" container="$2" cmd="$3"
    if [ "$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null)" != "true" ]; then
        echo "    skip ${name}: ${container} is not running (volume copy is consistent)"
        return
    fi
    docker exec "${container}" sh -c "${cmd}" | gzip -6 | remote "cat > ${DUMP_DIR}/${name}.sql.gz"
    echo "    ${name}.sql.gz: $(remote "stat -c %s ${DUMP_DIR}/${name}.sql.gz") bytes"
}
dump linux-lab-postgres linux-lab-postgres-1 'pg_dumpall -U "$POSTGRES_USER"'
dump camping-postgres camping_postgres 'pg_dumpall -U "$POSTGRES_USER"'
dump agrolink-mariadb agrolink-database \
    'mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction --routines --events'

echo "==> Copying volumes"
failed=0
for vol in "${VOLUMES[@]}"; do
    running="$(docker ps -q --filter "volume=${vol}")"
    [ -n "${running}" ] && docker stop ${running} >/dev/null

    labels="$(docker volume inspect -f '{{range $k, $v := .Labels}}--label {{$k}}={{$v}} {{end}}' "${vol}")"
    remote "docker volume inspect ${vol} >/dev/null 2>&1 || docker volume create ${labels} ${vol} >/dev/null"

    docker run --rm -v "${vol}:/v:ro" "${HELPER}" tar -C /v -cf - . \
        | remote "docker run --rm -i -v ${vol}:/v ${HELPER} tar -C /v -xpf -"

    local_sum="$(docker run --rm -v "${vol}:/v:ro" "${HELPER}" sh -c "${CHECKSUM_CMD}")"
    remote_sum="$(remote "docker run --rm -v ${vol}:/v:ro ${HELPER} sh -c '${CHECKSUM_CMD}'")"

    [ -n "${running}" ] && docker start ${running} >/dev/null

    if [ "${local_sum}" = "${remote_sum}" ]; then
        echo "    OK       ${vol}"
    else
        echo "    MISMATCH ${vol} (local ${local_sum} / remote ${remote_sum})"
        failed=1
    fi
done

[ "${failed}" -eq 0 ] && echo "All volumes match." || { echo "Some volumes differ." >&2; exit 1; }
