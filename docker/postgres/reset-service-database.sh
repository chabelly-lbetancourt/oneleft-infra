#!/usr/bin/env bash
# Empties the schema of one service database so that Flyway recreates it on the next start.
# Needed after rewriting migrations that were already applied (for example, when they were renamed).
# Local development only. Usage: postgres/reset-service-database.sh <users|plans|notifications>   (from oneleft-infra/docker)
set -euo pipefail
DB=${1:?"Usage: $0 <users|plans|notifications>"}
case "$DB" in users|plans|notifications) ;; *) echo "Unknown service database: $DB" >&2; exit 1 ;; esac
docker exec oneleft-postgres psql -U "${POSTGRES_USER:-oneleft}" -d "$DB" -q \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
if [ "$DB" = plans ]; then
  docker exec oneleft-postgres psql -U "${POSTGRES_USER:-oneleft}" -d plans -q -c "CREATE EXTENSION IF NOT EXISTS postgis;"
fi
echo "Database '$DB' emptied: restart the service to run its Flyway migrations."
