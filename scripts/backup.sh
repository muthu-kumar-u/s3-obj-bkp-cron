#!/bin/sh
set -eu
umask 077
config=${1:-/etc/application-backup/backup.env}
[ -r "$config" ] || { echo "Backup configuration unavailable" >&2; exit 2; }
set -a
# shellcheck source=/dev/null
. "$config"
set +a
: "${BACKUP_SOURCE:?}" "${BACKUP_HOST:?}" "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}"
state=${BACKUP_STATE_DIR:-/var/lib/application-backup}
mkdir -p "$state"
chmod 700 "$state"
exec 9>"$state/backup.lock"
flock -n 9 || { echo "Another backup is active" >&2; exit 75; }
finish() {
  result=$?
  trap - EXIT INT TERM HUP
  printf '%s\n' "$result" > "$state/last-exit-code"
  exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
if [ -n "${PRE_BACKUP_SCRIPT:-}" ]; then
  [ -x "$PRE_BACKUP_SCRIPT" ] || { echo "Preparation script is not executable" >&2; exit 2; }
  "$PRE_BACKUP_SCRIPT"
fi
[ -d "$BACKUP_SOURCE" ] || { echo "Backup source is not a directory" >&2; exit 2; }
(cd "$BACKUP_SOURCE" && restic backup . --host "$BACKUP_HOST" --tag scheduled)
restic check
if [ "${APPLY_RETENTION:-0}" -eq 1 ]; then
  restic forget --host "$BACKUP_HOST" --tag scheduled --group-by host,tags \
    --keep-daily "${KEEP_DAILY:-7}" --keep-weekly "${KEEP_WEEKLY:-4}" --prune
fi
date -u +%Y-%m-%dT%H:%M:%SZ > "$state/last-success"
echo "Encrypted backup completed"
