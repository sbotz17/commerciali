#!/usr/bin/env python3
"""Rimuove utenti e membership di test rimasti su staging.

Cerca in `utenti` i profili con email `@commerciali.test` o username `e2e-`,
elimina tutte le loro membership, i documenti personali collegati e l'account
Firebase Auth. Non tocca utenti reali, aziende, clienti, preventivi o altri dati.

Uso: python3 scripts/pulisci-dati-test.py
"""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "commerciali-app"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def access_token():
    path = os.path.expanduser("~/.config/configstore/firebase-tools.json")
    tokens = json.load(open(path))["tokens"]
    token = tokens["access_token"]
    if float(tokens.get("expires_at", 0)) <= time.time() * 1000 + 60_000:
        secret = os.environ.get("FIREBASE_CLI_CLIENT_SECRET")
        if not secret:
            raise RuntimeError(
                "Token Firebase CLI scaduto: imposta FIREBASE_CLI_CLIENT_SECRET"
            )
        body = urllib.parse.urlencode({
            "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
            "client_secret": secret,
            "refresh_token": tokens["refresh_token"],
            "grant_type": "refresh_token",
        }).encode()
        token = json.load(urllib.request.urlopen(
            urllib.request.Request("https://oauth2.googleapis.com/token", data=body)
        ))["access_token"]
    return token


def call(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def documents(collection, token):
    st, body = call("GET", f"{BASE}/{collection}?pageSize=300", token)
    if st != 200:
        return []
    return body.get("documents", [])


def string_field(doc, name):
    return doc.get("fields", {}).get(name, {}).get("stringValue", "")


def is_test_user(doc):
    email = string_field(doc, "email").lower()
    username = string_field(doc, "username").lower()
    return email.endswith("@commerciali.test") or username.startswith("e2e-")


def main():
    token = access_token()
    utenti = documents("utenti", token)
    test_uids = {d["name"].split("/")[-1] for d in utenti if is_test_user(d)}
    if not test_uids:
        print("Nessun utente di test trovato.")
        return 0

    print("Utenti di test:", ", ".join(sorted(test_uids)))
    rimosse = 0

    # Tutte le membership, anche quelle finite per errore in un'azienda reale.
    for doc in documents("membri", token):
        if string_field(doc, "utente_id") in test_uids:
            st, _ = call("DELETE", f"https://firestore.googleapis.com/v1/{doc['name']}", token)
            if st == 200:
                rimosse += 1

    # Documenti personali collegati all'utente.
    for collection, field in [
        ("impostazioni_notifiche", "utente_uid"),
        ("dispositivi", "utente_uid"),
        ("integrazioni", "utente_uid"),
        ("notifiche", "utente_uid"),
    ]:
        for doc in documents(collection, token):
            if string_field(doc, field) in test_uids:
                st, _ = call("DELETE", f"https://firestore.googleapis.com/v1/{doc['name']}", token)
                if st == 200:
                    rimosse += 1

    for uid in test_uids:
        call("DELETE", f"{BASE}/utenti/{uid}", token)
        call(
            "POST",
            f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:delete",
            token,
            {"localId": uid},
        )

    print(f"Pulizia completata: {rimosse} documenti e {len(test_uids)} account rimossi.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
