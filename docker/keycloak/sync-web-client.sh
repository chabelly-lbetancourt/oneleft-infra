#!/usr/bin/env bash
# Applies to a running Keycloak the redirect URIs and web origins of the oneleft-web client
# defined in oneleft-realm.json (the realm is only imported on the first start).
# Usage: keycloak/sync-web-client.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$KC/admin/realms/oneleft/clients?clientId=oneleft-web" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
BODY=$(python3 - <<'PY'
import json
client = next(c for c in json.load(open("keycloak/oneleft-realm.json"))["clients"] if c["clientId"] == "oneleft-web")
print(json.dumps({"redirectUris": client["redirectUris"], "webOrigins": client["webOrigins"]}))
PY
)
CURRENT=$(curl -s -H "Authorization: Bearer $TOKEN" "$KC/admin/realms/oneleft/clients/$ID")
MERGED=$(python3 -c 'import json,sys; c=json.loads(sys.argv[1]); c.update(json.loads(sys.argv[2])); print(json.dumps(c))' "$CURRENT" "$BODY")
curl -s -o /dev/null -w "oneleft-web updated (HTTP %{http_code})\n" -X PUT \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$KC/admin/realms/oneleft/clients/$ID" -d "$MERGED"
