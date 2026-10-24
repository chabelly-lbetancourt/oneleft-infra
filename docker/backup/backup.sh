#!/bin/sh
# Copies every database of PostgreSQL and its roles (pg_dumpall, gzip) to s3://$BACKUP_BUCKET/postgres/ every day at
# $BACKUP_TIME (UTC) and deletes the copies older than $BACKUP_KEEP_DAYS days.
#   backup.sh        waits for each $BACKUP_TIME and makes the copy (the container's command)
#   backup.sh now    makes one copy straight away and exits (docker compose run --rm backup now)
# BACKUP_ENDPOINT is only needed for buckets outside AWS (the local S3 gateway); the PG* and AWS_* variables come from
# the environment.
set -eu

: "${BACKUP_BUCKET:?BACKUP_BUCKET is required}"
BACKUP_TIME="${BACKUP_TIME:-03:00}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
PREFIX=postgres

s3() {
  if [ -n "${BACKUP_ENDPOINT:-}" ]; then aws --endpoint-url "$BACKUP_ENDPOINT" "$@"; else aws "$@"; fi
}

backup() {
  key="$PREFIX/oneleft-$(date -u +%Y-%m-%dT%H%M%SZ).sql.gz"
  pg_dumpall | gzip -9 | s3 s3 cp - "s3://$BACKUP_BUCKET/$key" --only-show-errors
  echo "$(date -u +%FT%TZ) backup: s3://$BACKUP_BUCKET/$key"
  prune
}

# Deletes the copies older than BACKUP_KEEP_DAYS: the digits of each name are its date and time (YYYYmmddHHMMSS)
prune() {
  cutoff=$(date -u -d "@$(( $(date -u +%s) - BACKUP_KEEP_DAYS * 86400 ))" +%Y%m%d%H%M%S)
  s3 s3api list-objects-v2 --bucket "$BACKUP_BUCKET" --prefix "$PREFIX/oneleft-" --query 'Contents[].Key' \
      --output text | tr '\t' '\n' | while read -r old; do
    stamp=$(printf '%s' "$old" | tr -cd '0-9')
    if [ -n "$stamp" ] && [ "$stamp" -lt "$cutoff" ]; then
      s3 s3 rm "s3://$BACKUP_BUCKET/$old" --only-show-errors
      echo "$(date -u +%FT%TZ) backup: deleted $old"
    fi
  done
}

# Seconds until the next BACKUP_TIME (UTC)
seconds_until_next() {
  now=$(date -u +%s)
  next=$(date -u -d "$(date -u +%Y-%m-%d) $BACKUP_TIME" +%s)
  [ "$next" -gt "$now" ] || next=$((next + 86400))
  echo $((next - now))
}

if [ "${1:-}" = now ]; then
  backup
  exit 0
fi

# docker compose stop ends the wait at once
trap 'exit 0' TERM INT
echo "$(date -u +%FT%TZ) backup: every day at $BACKUP_TIME UTC, keeping $BACKUP_KEEP_DAYS days"
while true; do
  sleep "$(seconds_until_next)" &
  wait $!
  backup || echo "$(date -u +%FT%TZ) backup: FAILED" >&2
done
