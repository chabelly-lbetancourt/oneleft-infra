#!/usr/bin/env bash
# Applies to a running Keycloak the oneleft-accounts client of oneleft-realm.json, with which the users service
# deletes accounts (HU-045). The realm is only imported the first time, so a Keycloak that already exists needs it.
# The client uses client credentials, and its service account can only manage users. Safe to repeat.
# Usage: keycloak/sync-accounts-client.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
SECRET="${ACCOUNTS_CLIENT_SECRET:-oneleft-accounts-dev}"
api() { curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$@"; }
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
ID=$(api "$KC/admin/realms/oneleft/clients?clientId=oneleft-accounts" | python3 -c 'import json,sys; c=json.load(sys.stdin); print(c[0]["id"] if c else "")')
if [ -z "$ID" ]; then
  python3 - "$SECRET" <<'PY' | api -X POST "$KC/admin/realms/oneleft/clients" --data @- -o /dev/null
import json, sys
client = next(c for c in json.load(open("keycloak/oneleft-realm.json"))["clients"] if c["clientId"] == "oneleft-accounts")
client["secret"] = sys.argv[1]
print(json.dumps(client))
PY
  ID=$(api "$KC/admin/realms/oneleft/clients?clientId=oneleft-accounts" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
  echo "client created"
else
  echo "client already there"
fi
SA=$(api "$KC/admin/realms/oneleft/clients/$ID/service-account-user" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
RM=$(api "$KC/admin/realms/oneleft/clients?clientId=realm-management" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
ROLE=$(api "$KC/admin/realms/oneleft/clients/$RM/roles/manage-users")
echo "[$ROLE]" | api -X POST "$KC/admin/realms/oneleft/users/$SA/role-mappings/clients/$RM" --data @- -o /dev/null
echo "service account may manage users"
