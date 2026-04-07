#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyjwt[crypto]>=2.8.0", "requests>=2.31"]
# ///
"""
Tiny App Store Connect API helper.

Reads credentials from env:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH

Subcommands:
  list-bundles
  create-bundle  <identifier> <name>
  list-apps
  create-app     <bundleId> <name> <sku> <primaryLocale> <platform>
"""
import os, sys, json, time, jwt, requests, pathlib

KEY_ID    = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
KEY_PATH  = os.environ["ASC_KEY_PATH"]
BASE      = "https://api.appstoreconnect.apple.com/v1"

def token():
    pem = pathlib.Path(KEY_PATH).read_bytes()
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 20 * 60,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, pem, algorithm="ES256",
                      headers={"kid": KEY_ID, "typ": "JWT"})

def call(method, path, body=None):
    url = BASE + path
    headers = {
        "Authorization": f"Bearer {token()}",
        "Content-Type": "application/json",
    }
    r = requests.request(method, url, headers=headers,
                         data=json.dumps(body) if body else None)
    if r.status_code >= 400:
        print(f"HTTP {r.status_code}", file=sys.stderr)
        print(r.text, file=sys.stderr)
        sys.exit(1)
    return r.json() if r.text else {}

def cmd_list_bundles():
    data = call("GET", "/bundleIds?limit=200")
    for b in data.get("data", []):
        a = b["attributes"]
        print(f'{b["id"]}\t{a.get("identifier")}\t{a.get("name")}\t{a.get("platform")}')

def cmd_create_bundle(identifier, name):
    body = {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": identifier,
                "name": name,
                "platform": "MAC_OS",
            },
        }
    }
    data = call("POST", "/bundleIds", body)
    print(json.dumps(data, indent=2))

def cmd_list_apps():
    data = call("GET", "/apps?limit=200")
    for a in data.get("data", []):
        attr = a["attributes"]
        print(f'{a["id"]}\t{attr.get("bundleId")}\t{attr.get("name")}\t{attr.get("sku")}')

def cmd_create_app(bundle_id, name, sku, primary_locale, platform):
    # Note: App Store Connect API may not support creating apps for all account types.
    body = {
        "data": {
            "type": "apps",
            "attributes": {
                "bundleId": bundle_id,
                "name": name,
                "sku": sku,
                "primaryLocale": primary_locale,
            },
        }
    }
    data = call("POST", "/apps", body)
    print(json.dumps(data, indent=2))

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    cmd = sys.argv[1]
    args = sys.argv[2:]
    table = {
        "list-bundles": (cmd_list_bundles, 0),
        "create-bundle": (cmd_create_bundle, 2),
        "list-apps": (cmd_list_apps, 0),
        "create-app": (cmd_create_app, 5),
    }
    if cmd not in table:
        print("unknown:", cmd); sys.exit(1)
    fn, n = table[cmd]
    if len(args) != n:
        print(f"{cmd} expects {n} args"); sys.exit(1)
    fn(*args)

if __name__ == "__main__":
    main()
