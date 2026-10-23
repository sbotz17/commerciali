#!/usr/bin/env python3
"""Deploy hosting del sito Flutter via Firebase Hosting REST API.

Serve quando `firebase deploy` non riesce a rinnovare le credenziali CLI.
Usa il refresh token già presente nella configurazione di firebase-tools.

Uso: python3 scripts/deploy_hosting_rest.py
"""
import gzip
import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "commerciali-app"
SITE = sys.argv[1] if len(sys.argv) > 1 else "commerciali-flutter"
API = "https://firebasehosting.googleapis.com/v1beta1"
PUBLIC = pathlib.Path("flutter_app/build/web")


def access_token():
    path = os.path.expanduser("~/.config/configstore/firebase-tools.json")
    tokens = json.load(open(path))["tokens"]
    body = urllib.parse.urlencode({
        "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
        "client_secret": "j9iVZfS8kkCEFUPaAeJV0sAi",
        "refresh_token": tokens["refresh_token"],
        "grant_type": "refresh_token",
    }).encode()
    return json.load(urllib.request.urlopen(
        urllib.request.Request("https://oauth2.googleapis.com/token", data=body)
    ))["access_token"]


def call(method, url, token, body=None, raw=None, content_type="application/json"):
    data = raw if raw is not None else (
        json.dumps(body).encode() if body is not None else None
    )
    headers = {"Authorization": "Bearer " + token}
    if data is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            payload = r.read().decode()
            return r.status, (json.loads(payload) if payload else {})
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:2000])
        raise


def main():
    if not PUBLIC.is_dir():
        print("Cartella build mancante:", PUBLIC)
        return 1
    token = access_token()
    base = f"{API}/projects/{PROJECT}/sites/{SITE}"

    st, version = call("POST", f"{base}/versions", token, {"status": "CREATED"})
    version_name = version["name"]
    version_id = version_name.rsplit("/", 1)[-1]
    print("versione", version_id)

    files = {}
    contents = {}
    for path in sorted(PUBLIC.rglob("*")):
        if not path.is_file() or any(part.startswith(".") for part in path.parts):
            continue
        rel = "/" + path.relative_to(PUBLIC).as_posix()
        raw = path.read_bytes()
        gz = gzip.compress(raw, compresslevel=9)
        digest = hashlib.sha256(gz).hexdigest()
        files[rel] = digest
        contents[digest] = gz

    st, populated = call(
        "POST", f"{base}/versions/{version_id}:populateFiles", token, {"files": files}
    )
    upload_url = populated["uploadUrl"]
    for digest in populated.get("uploadRequiredHashes") or []:
        call(
            "POST",
            f"{upload_url}/{digest}",
            token,
            raw=contents[digest],
            content_type="application/octet-stream",
        )
    print("file caricati", len(files))

    config = {
        "rewrites": [{"glob": "**", "path": "/index.html"}],
        "headers": [
            {
                "glob": source,
                "headers": {"Cache-Control": "no-cache, no-store, must-revalidate"},
            }
            for source in (
                "/index.html",
                "/flutter_bootstrap.js",
                "/main.dart.js",
                "/flutter_service_worker.js",
            )
        ],
    }
    call(
        "PATCH",
        f"{base}/versions/{version_id}?updateMask=status,config",
        token,
        {"status": "FINALIZED", "config": config},
    )
    print("versione finalizzata")

    call(
        "POST",
        f"{base}/channels/live/releases?versionName={urllib.parse.quote(version_name, safe='')}",
        token,
        {},
    )
    print("release completata")
    return 0


if __name__ == "__main__":
    sys.exit(main())
