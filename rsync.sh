#!/bin/sh
#
# rsync.sh
# Pulls a folder of media from a remote host over SSH using rsync, mirroring
# it into a local folder (files removed on the server are removed locally).
#
# Site-specific settings live in sync.conf, in the same folder as this script.
# See sync.conf.example for the settings it must define.
#
# Safeguards:
#   - Aborts if the source folder on the server is not a mounted filesystem,
#     so an unmounted share can never be mirrored as "empty" and wipe the
#     local copy.
#   - Retries up to 5 times on connection failures, resuming interrupted
#     files from their partial copies.
#

PATH=/sbin:/usr/sbin:/usr/bin:/usr/local/bin

# Patterns in EXCLUDES are passed to rsync, never expanded by this shell.
set -f

# ---- Load this machine's settings ----
CONF="$(dirname "$0")/rsync.conf"
if [ ! -r "$CONF" ]; then
  echo "ABORT: config file $CONF not found or not readable. No sync performed."
  exit 1
fi
. "$CONF"

for var in SERVER SRC_DIR DEST; do
  eval "val=\$$var"
  if [ -z "$val" ]; then
    echo "ABORT: $var is not set in $CONF. No sync performed."
    exit 1
  fi
done

EXCLUDE_OPTS=""
for pattern in $EXCLUDES; do
  EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude=$pattern"
done

SSH_CMD="ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=4"

# rsync's output is captured here and filtered before printing, so the
# retry logic below still sees rsync's real exit code.
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

# Statistics lines to leave out of the email. Blank lines are also removed.
HIDE='^(Number of files:|Number of created files:|Total file size:|Literal data:|Matched data:|File list size:|File list generation time:|File list transfer time:|Total bytes sent:|Total bytes received:|sent [0-9,]+ bytes|total size is |$)'

echo "Sync started $(date)"

# Refuse to sync if the share isn't mounted on the server.
# An unmounted mount point is an empty directory, and --delete would mirror that.
if ! $SSH_CMD "$SERVER" "mountpoint -q $SRC_DIR"; then
  echo "ABORT: $SRC_DIR is not mounted on $SERVER (or server unreachable). No sync performed."
  exit 1
fi

for attempt in 1 2 3 4 5; do
  rsync -v -rlt --chmod=a=rw,Da+x --delete --max-delete=100 \
        --partial-dir=.rsync-partial --timeout=300 --stats \
        $EXCLUDE_OPTS \
        -e "$SSH_CMD" \
        "$SERVER:$SRC_DIR/" "$DEST" > "$OUT" 2>&1
  rc=$?
  grep -v -E "$HIDE" "$OUT"
  echo "Attempt $attempt finished $(date) with exit code $rc"
  [ $rc -eq 0 ] && break
  case $rc in
    12|30|35|255) sleep 60 ;;   # transport failures: retry
    *) break ;;                 # real errors: stop and report
  esac
done

echo "Sync ended $(date), final exit code $rc"
exit $rc
