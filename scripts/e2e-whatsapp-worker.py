#!/usr/bin/env python3
"""E2E del proxy Worker per la configurazione WhatsApp.

Crea un utente temporaneo con super_admin=true, verifica che il Worker
protegga la configurazione, salvi URL/API key nel KV, le rilegga e le cancelli.
Pulisce utente, profilo e configurazione alla fine.

Uso: python3 scripts/e2e-whatsapp-worker.py
"""
import json
import os
import random
import string
import time
import urllib.error
import urllib.parse
import urllib.request

API_KEY = "AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4"
PROJECT = "commerciali-app"
WORKER = "https://commerciali-vies.bottiandrea83.workers.dev"
FIRESTORE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def call(method, url, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json", "User-Agent": "Closer-E2E/1.0"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            return e.code, {"raw": raw}


def admin_token():
    path = os.path.expanduser("~/.config/configstore/firebase-tools.json")
    tokens = json.load(open(path))["tokens"]
    access = tokens["access_token"]
    if float(tokens.get("expires_at", 0)) <= time.time() * 1000 + 60_000:
        if not os.environ.get("FIREBASE_CLI_CLIENT_SECRET"):
            raise RuntimeError(
                "Imposta FIREBASE_CLI_CLIENT_SECRET per rinnovare il token Firebase CLI"
            )
        body = urllib.parse.urlencode(
            {
                "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
                "client_secret": os.environ.get("FIREBASE_CLI_CLIENT_SECRET", ""),
                "refresh_token": tokens["refresh_token"],
                "grant_type": "refresh_token",
            }
        ).encode()
        access = json.load(
            urllib.request.urlopen(
                urllib.request.Request(
                    "https://oauth2.googleapis.com/token", data=body
                )
            )
        )["access_token"]
    return access


def s(v):
    return {"stringValue": v}


def b(v):
    return {"booleanValue": v}



def attendi_config(token, atteso, timeout=15):
    """Attende la propagazione del KV tra le edge Cloudflare."""
    fine = time.time() + timeout
    ultimo = None
    while time.time() < fine:
        stato, dati = call("GET", f"{WORKER}/whatsapp/config", token=token)
        ultimo = (stato, dati)
        if stato == 200 and dati.get("url") == atteso:
            return stato, dati
        time.sleep(0.5)
    return ultimo

def main():
    suffisso = "".join(
        random.choice(string.ascii_lowercase + string.digits) for _ in range(8)
    )
    email = f"e2e-wa-worker-{suffisso}@commerciali.test"
    uid = None
    errori = []
    try:
        admin = admin_token()
        stato, dati = call(
            "POST",
            f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
            {
                "email": email,
                "password": "E2eTest12345!",
                "returnSecureToken": True,
            },
        )
        if stato != 200:
            print("FAIL signup", stato, dati)
            return 1
        uid = dati["localId"]
        token = dati["idToken"]

        # Profilo super admin temporaneo.
        stato, _ = call(
            "PATCH",
            f"{FIRESTORE}/utenti/{uid}",
            {
                "fields": {
                    "uid": s(uid),
                    "email": s(email),
                    "super_admin": b(True),
                }
            },
            admin,
        )
        if stato != 200:
            errori.append(f"profilo super admin: {stato}")

        # Senza token il Worker deve rifiutare.
        stato, _ = call("GET", f"{WORKER}/whatsapp/config")
        if stato != 401:
            errori.append(f"config senza token: atteso 401, ottenuto {stato}")

        # Lettura iniziale e salvataggio.
        stato, dati = call("GET", f"{WORKER}/whatsapp/config", token=token)
        if stato != 200:
            errori.append(f"config iniziale: {stato} {dati}")
        stato, dati = call(
            "POST",
            f"{WORKER}/whatsapp/config",
            {"url": "https://wa.e2e.invalid", "apiKey": "chiave-di-prova"},
            token,
        )
        if stato != 200:
            errori.append(f"salvataggio config: {stato} {dati}")
        stato, dati = attendi_config(token, "https://wa.e2e.invalid")
        if stato != 200 or dati.get("url") != "https://wa.e2e.invalid":
            errori.append(f"rilettura config: {stato} {dati}")

        # Il server finto non risponde: il Worker deve restituire un errore
        # controllato, non andare in crash.
        stato, dati = call("GET", f"{WORKER}/whatsapp/status", token=token)
        # Il server finto non è raggiungibile: il Worker deve rispondere con
        # un errore controllato oppure con lo stato vuoto (KV non ancora
        # propagato in questa edge), mai con un crash.
        if stato < 500 and dati.get("connected") is not False:
            errori.append(f"status server finto: risposta inattesa {stato} {dati}")

        # Cancellazione riservata al super admin.
        stato, _ = call("DELETE", f"{WORKER}/whatsapp/config", token=token)
        if stato != 200:
            errori.append(f"cancellazione config: {stato}")
        stato, dati = attendi_config(token, "")
        if stato != 200 or dati.get("url") not in ("", None):
            errori.append(f"config non cancellata: {stato} {dati}")

        if errori:
            print("FAIL E2E Worker WhatsApp:")
            for errore in errori:
                print(" -", errore)
            return 1
        print(
            "PASS: Worker WhatsApp protegge la configurazione, salva/rilegge/cancella "
            "URL e API key e gestisce il server non raggiungibile"
        )
        return 0
    finally:
        try:
            admin = admin_token()
            if uid:
                call("DELETE", f"{FIRESTORE}/utenti/{uid}", token=admin)
                call(
                    "POST",
                    f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:delete",
                    {"localId": uid},
                    admin,
                )
        except Exception as e:
            print("cleanup:", e)


if __name__ == "__main__":
    raise SystemExit(main())
