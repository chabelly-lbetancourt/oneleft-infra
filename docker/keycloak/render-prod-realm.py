#!/usr/bin/env python3
"""Builds the realm of the deployed environments (oneleft-realm.prod.json) from the development one.

The development realm carries test users with known passwords, a test client with its secret and the local URLs of
the web. The deployed realm keeps everything else (the web client, scopes, theme, Google, SMTP placeholders, and the
client with which the users service deletes accounts) but has no test users and no test client, and the web client
only accepts the public origin, which Keycloak fills in from ONELEFT_DOMAIN when it imports the realm.

Usage (from oneleft-infra/docker): keycloak/render-prod-realm.py          writes oneleft-realm.prod.json
                                   keycloak/render-prod-realm.py --check  fails if it is out of date (CI)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "oneleft-realm.json"
TARGET = HERE / "oneleft-realm.prod.json"
ORIGIN = "https://${ONELEFT_DOMAIN}"
# The Android app signs in through the system browser and comes back to oneleft://callback; its WebView calls
# Keycloak from https://localhost, so that origin stays allowed for CORS
ANDROID_REDIRECT = "oneleft://*"
ANDROID_ORIGIN = "https://localhost"


def render() -> str:
    realm = json.loads(SOURCE.read_text(encoding="utf-8"))
    # No test users; the service account of oneleft-accounts stays, because the client needs it to delete accounts
    realm["users"] = [
        user for user in realm.get("users", []) if user.get("serviceAccountClientId") == "oneleft-accounts"
    ]
    # oneleft-api only serves local tests (password grant with a secret in the repository): not deployed
    realm["clients"] = [client for client in realm["clients"] if client["clientId"] != "oneleft-api"]
    # The secret of that client has no default here: without ACCOUNTS_CLIENT_SECRET the import fails, instead of
    # deploying the development one
    accounts = next(client for client in realm["clients"] if client["clientId"] == "oneleft-accounts")
    accounts["secret"] = "${ACCOUNTS_CLIENT_SECRET}"
    web = next(client for client in realm["clients"] if client["clientId"] == "oneleft-web")
    web["redirectUris"] = [f"{ORIGIN}/*", ANDROID_REDIRECT, f"{ORIGIN}/swagger-ui/oauth2-redirect.html"]
    web["webOrigins"] = [ORIGIN, ANDROID_ORIGIN]
    web["attributes"]["post.logout.redirect.uris"] = f"{ORIGIN}/*##{ANDROID_REDIRECT}"
    text = json.dumps(realm, indent=2, ensure_ascii=False) + "\n"
    if "http://localhost" in text:
        sys.exit("render-prod-realm: the development realm has a new local URL; map it in render() first")
    return text


def main() -> None:
    text = render()
    if "--check" in sys.argv[1:]:
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != text:
            sys.exit(f"{TARGET.name} is out of date: run keycloak/render-prod-realm.py and commit it")
        print(f"{TARGET.name} is up to date")
        return
    TARGET.write_text(text, encoding="utf-8")
    print(f"{TARGET.name} written")


if __name__ == "__main__":
    main()
