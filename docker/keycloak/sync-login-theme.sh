#!/usr/bin/env bash
# Applies to a running Keycloak the login theme defined in oneleft-realm.json (the realm is only imported on the
# first start). The theme itself is mounted by Docker Compose from keycloak/themes.
# Usage: keycloak/sync-login-theme.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
THEME=$(python3 -c 'import json; print(json.load(open("keycloak/oneleft-realm.json"))["loginTheme"])')
curl -s -o /dev/null -w "login theme $THEME (HTTP %{http_code})\n" -X PUT \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$KC/admin/realms/oneleft" -d "{\"loginTheme\": \"$THEME\"}"
