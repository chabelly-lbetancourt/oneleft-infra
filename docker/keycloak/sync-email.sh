#!/usr/bin/env bash
# Applies to a running Keycloak the email settings of oneleft-realm.json (the realm is only imported on the first
# start): the SMTP server, email verification and password reset. The ${VAR:default} placeholders are replaced with
# the variables of .env, falling back to their default (Mailpit) when a variable is empty, as Docker Compose does.
# Usage: keycloak/sync-email.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
BODY=$(python3 - <<'PY'
import json, os, re

def resolve(value):
    return re.sub(r"\$\{([A-Z0-9_]+)(?::([^}]*))?\}", lambda m: os.environ.get(m.group(1)) or m.group(2) or "", value)

realm = json.load(open("keycloak/oneleft-realm.json"))
print(json.dumps({"verifyEmail": realm["verifyEmail"], "resetPasswordAllowed": realm["resetPasswordAllowed"],
                  "smtpServer": {key: resolve(value) for key, value in realm["smtpServer"].items()}}))
PY
)
curl -s -o /dev/null -w "email settings, SMTP ${SMTP_HOST:-mailpit}:${SMTP_PORT:-1025} (HTTP %{http_code})\n" -X PUT \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$KC/admin/realms/oneleft" -d "$BODY"
