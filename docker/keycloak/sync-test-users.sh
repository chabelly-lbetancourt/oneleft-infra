#!/usr/bin/env bash
# Adds to a running Keycloak the test users of oneleft-realm.json that it does not have yet (the realm is only
# imported on the first start). Existing users are left untouched. Development only.
# Usage: keycloak/sync-test-users.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
python3 -c 'import json; print(json.dumps({"ifResourceExists": "SKIP", "users": json.load(open("keycloak/oneleft-realm.json"))["users"]}))' \
  | curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      "$KC/admin/realms/oneleft/partialImport" --data @- \
  | python3 -c 'import json,sys; r=json.load(sys.stdin); print("test users:", r.get("added", 0), "added,", r.get("skipped", 0), "already there")'
