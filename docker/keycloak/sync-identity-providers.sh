#!/usr/bin/env bash
# Applies to a running Keycloak the identity providers defined in oneleft-realm.json (the realm is only imported
# on the first start). The ${VAR} placeholders are replaced with the variables of .env, as the import does.
# Existing providers are updated in place, so the accounts already linked to them are kept.
# Usage: keycloak/sync-identity-providers.sh   (from oneleft-infra/docker, with .env loaded)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
KC=http://localhost:8180
TOKEN=$(curl -s -X POST "$KC/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username="$KEYCLOAK_ADMIN" --data-urlencode password="$KEYCLOAK_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
export TOKEN KC
python3 - <<'PY'
import json, os, re, urllib.error, urllib.request

def resolve(value):
    if isinstance(value, dict):
        return {key: resolve(item) for key, item in value.items()}
    if isinstance(value, str):
        return re.sub(r"\$\{([A-Z0-9_]+)(?::([^}]*))?\}", lambda m: os.environ.get(m.group(1), m.group(2) or ""), value)
    return value

def call(method, path, body=None):
    request = urllib.request.Request(os.environ["KC"] + "/admin/realms/oneleft" + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": "Bearer " + os.environ["TOKEN"],
                                              "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code

for provider in json.load(open("keycloak/oneleft-realm.json")).get("identityProviders", []):
    provider = resolve(provider)
    alias = provider["alias"]
    if not provider["config"].get("clientSecret"):
        print(f"{alias}: skipped, its client secret is not in .env")
        continue
    if call("GET", f"/identity-provider/instances/{alias}") == 200:
        print(f"{alias} updated (HTTP {call('PUT', f'/identity-provider/instances/{alias}', provider)})")
    else:
        print(f"{alias} created (HTTP {call('POST', '/identity-provider/instances', provider)})")
PY
