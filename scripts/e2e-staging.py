#!/usr/bin/env python3
"""E2E staging: verifica che un utente normale possa leggere/scrivere i propri dati.

Crea un utente e un'azienda temporanei, fa login come quell'utente e prova un CRUD
cliente tramite le Security Rules reali di Firestore. Pulisce tutto alla fine.

Uso: python3 scripts/e2e-staging.py
Esito: 0 = PASS, 1 = FAIL (stampa il corpo dell'errore, mai token o password).
"""
import json
import os
import random
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_KEY = "AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4"
PROJECT = "commerciali-app"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def call(method, url, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def admin_token():
    path = os.path.expanduser("~/.config/configstore/firebase-tools.json")
    tokens = json.load(open(path))["tokens"]
    access = tokens["access_token"]
    if float(tokens.get("expires_at", 0)) <= time.time() * 1000 + 60_000:
        if not os.environ.get("FIREBASE_CLI_CLIENT_SECRET"):
            raise RuntimeError("Imposta FIREBASE_CLI_CLIENT_SECRET per rinnovare il token Firebase CLI")
        body = urllib.parse.urlencode({
            "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
            "client_secret": os.environ.get("FIREBASE_CLI_CLIENT_SECRET", ""),
            "refresh_token": tokens["refresh_token"],
            "grant_type": "refresh_token",
        }).encode()
        access = json.load(urllib.request.urlopen(
            urllib.request.Request("https://oauth2.googleapis.com/token", data=body)
        ))["access_token"]
    return access


def s(v):
    return {"stringValue": v}


def b(v):
    return {"booleanValue": v}


def main():
    suffix = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    email = f"e2e-{suffix}@commerciali.test"
    password = "E2eTest12345!"
    uid = az = cliente_id = None
    errori = []
    try:
        admin = admin_token()

        # 1. utente Auth
        st, d = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                     {"email": email, "password": password, "returnSecureToken": True})
        if st != 200:
            print("FAIL signup:", st, d)
            return 1
        uid = d["localId"]
        print("utente creato")

        # 2. profilo, azienda, membership, licenza
        az = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(20))
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        writes = []
        def w(path, fields):
            writes.append({"update": {
                "name": f"projects/{PROJECT}/databases/(default)/documents/{path}",
                "fields": fields,
            }})
        w(f"utenti/{uid}", {
            "uid": s(uid), "email": s(email), "username": s("e2e"), "nome": s("E2E"),
            "ruolo": s("admin"), "attivo": b(True), "super_admin": b(False), "created_at": s(now),
        })
        w(f"aziende/{az}", {"nome": s("E2E Azienda"), "created_by": s(uid), "created_at": s(now)})
        w(f"membri/{az}_{uid}", {
            "azienda_id": s(az), "utente_id": s(uid), "ruolo": s("admin"), "created_at": s(now),
        })
        w(f"licenze/{az}", {
            "azienda_id": s(az), "piano": s("trial"), "stato": s("attiva"),
            "data_inizio": s(time.strftime("%Y-%m-%d", time.gmtime())),
            "data_fine": {"nullValue": None}, "max_utenti": {"integerValue": "2"},
            "max_preventivi": {"integerValue": "20"}, "updated_at": s(now),
        })
        st, d = call("POST", BASE + ":commit", {"writes": writes}, admin)
        if st != 200:
            print("FAIL setup dati:", st, d)
            return 1
        print("azienda e membership create")

        # 3. login come utente normale
        st, d = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}",
                     {"email": email, "password": password, "returnSecureToken": True})
        if st != 200:
            print("FAIL login:", st, d)
            return 1
        id_token = d["idToken"]

        # 4. CRUD cliente con le regole reali
        cliente_id = "e2e" + suffix
        doc = {
            "fields": {
                "azienda_id": s(az), "nome": s("Cliente E2E"), "piva": s("12345678901"),
                "created_at": s(now),
            }
        }
        st, d = call("POST", f"{BASE}/clienti?documentId={cliente_id}", doc, id_token)
        if st != 200:
            errori.append(f"create cliente: {st} {d}")
        else:
            print("create cliente: OK")

        st, d = call("GET", f"{BASE}/clienti/{cliente_id}", token=id_token)
        if st != 200:
            errori.append(f"read cliente: {st} {d}")
        else:
            print("read cliente: OK")

        patch = {"fields": {"nome": s("Cliente E2E modificato")}}
        st, d = call("PATCH", f"{BASE}/clienti/{cliente_id}?updateMask.fieldPaths=nome", patch, id_token)
        if st != 200:
            errori.append(f"update cliente: {st} {d}")
        else:
            print("update cliente: OK")

        st, d = call("DELETE", f"{BASE}/clienti/{cliente_id}", token=id_token)
        if st != 200:
            errori.append(f"delete cliente: {st} {d}")
        else:
            cliente_id = None
            print("delete cliente: OK")

        if errori:
            print("\nFAIL E2E:")
            for e in errori:
                print(" -", e)
            return 1
        print("\nPASS: permessi di lettura/scrittura corretti per un utente normale")
        return 0
    finally:
        # cleanup best-effort
        try:
            admin = admin_token()
            for path in filter(None, [
                f"clienti/{cliente_id}" if cliente_id else None,
                f"membri/{az}_{uid}" if az and uid else None,
                f"aziende/{az}" if az else None,
                f"licenze/{az}" if az else None,
                f"utenti/{uid}" if uid else None,
            ]):
                call("DELETE", f"{BASE}/{path}", token=admin)
            if uid:
                call("POST", f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:delete",
                     {"localId": uid}, admin)
        except Exception as e:
            print("cleanup:", e)


if __name__ == "__main__":
    sys.exit(main())
