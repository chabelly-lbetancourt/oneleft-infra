#!/usr/bin/env bash
# Generates the VAPID key pair of Web Push (HU-006) with openssl: a P-256 key whose public part is the uncompressed
# point (65 bytes) and whose private part is the raw scalar (32 bytes), both in base64url, as the notifications service
# and the browsers expect them.
#   ./generate-vapid-keys.sh           prints the two variables
#   ./generate-vapid-keys.sh --write   writes them to .env (next to this script), replacing previous ones
# The keys are secrets of each environment: never commit them. Changing them invalidates every browser subscription.
set -euo pipefail
cd "$(dirname "$0")"

base64url() { base64 | tr '+/' '-_' | tr -d '=\n'; }

pem="$(openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null)"
# SubjectPublicKeyInfo ends with the 65-byte uncompressed point
public="$(printf '%s\n' "$pem" | openssl ec -pubout -outform DER 2>/dev/null | tail -c 65 | base64url)"
# ECPrivateKey (RFC 5915): 30 77 02 01 01 04 20 <32-byte private key> ...
private="$(printf '%s\n' "$pem" | openssl ec -outform DER 2>/dev/null | tail -c +8 | head -c 32 | base64url)"

if [[ "${1:-}" == "--write" ]]; then
  [[ -f .env ]] || cp .env.example .env
  grep -v '^VAPID_PUBLIC_KEY=\|^VAPID_PRIVATE_KEY=' .env > .env.tmp || true
  printf 'VAPID_PUBLIC_KEY=%s\nVAPID_PRIVATE_KEY=%s\n' "$public" "$private" >> .env.tmp
  mv .env.tmp .env
  echo "VAPID keys written to docker/.env (restart notifications: docker compose --profile backend up -d notifications)"
else
  printf 'VAPID_PUBLIC_KEY=%s\nVAPID_PRIVATE_KEY=%s\n' "$public" "$private"
fi
