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
    config_originale = None
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

        # Backup della configurazione reale: il test non deve cancellarla.
        st, config_originale = call(
            "GET", f"{WORKER}/whatsapp/config", token=token
        )
        if st != 200:
            config_originale = None

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

        # Invio: il Worker legge il contatto con il token del chiamante.
        azienda = "e2e-wa-" + suffisso
        stato, _ = call(
            "PATCH",
            f"{FIRESTORE}/aziende/{azienda}",
            {"fields": {"nome": s("E2E WA"), "created_by": s(uid)}},
            admin,
        )
        if stato != 200:
            errori.append(f"azienda E2E: {stato}")
        stato, _ = call(
            "PATCH",
            f"{FIRESTORE}/membri/{azienda}_{uid}",
            {
                "fields": {
                    "azienda_id": s(azienda),
                    "utente_id": s(uid),
                    "ruolo": s("admin"),
                }
            },
            admin,
        )
        if stato != 200:
            errori.append(f"membership E2E: {stato}")
        stato, _ = call(
            "PATCH",
            f"{FIRESTORE}/contatti_notifiche/{azienda}_{uid}",
            {
                "fields": {
                    "azienda_id": s(azienda),
                    "utente_uid": s(uid),
                    "numero_whatsapp": s("393330000000"),
                    "consenso_whatsapp": b(True),
                }
            },
            admin,
        )
        if stato != 200:
            errori.append(f"contatto E2E: {stato}")
        stato, dati = call(
            "POST",
            f"{WORKER}/whatsapp/send",
            {
                "aziendaId": azienda,
                "utenteUid": uid,
                "message": "Test E2E",
            },
            token,
        )
        if stato < 400:
            errori.append(f"invio con server finto: atteso errore, ottenuto {stato} {dati}")

        # Cancellazione riservata al super admin.
        stato, _ = call("DELETE", f"{WORKER}/whatsapp/config", token=token)
        if stato != 200:
            errori.append(f"cancellazione config: {stato}")
        stato, dati = attendi_config(token, "")
        if stato != 200 or dati.get("url") not in ("", None):
            errori.append(f"config non cancellata: {stato} {dati}")

        # Allegati: upload autenticato nel KV, link firmato, download e delete.
        contenuto = b"allegato-e2e"
        richiesta = urllib.request.Request(
            f"{WORKER}/allegati/upload",
            data=contenuto,
            method="POST",
            headers={
                "Authorization": "Bearer " + token,
                "User-Agent": "Closer-E2E/1.0",
                "x-azienda-id": azienda,
                "x-elemento-id": "appuntamento-e2e",
                "x-elemento-tipo": "appuntamento",
                "x-nome": urllib.parse.quote("prova.txt"),
                "x-mime": "text/plain",
            },
        )
        try:
            with urllib.request.urlopen(richiesta, timeout=30) as r:
                caricato = json.loads(r.read().decode())
            if not caricato.get("id") or not caricato.get("objectKey"):
                errori.append(f"upload allegato incompleto: {caricato}")
            else:
                stato, link = call(
                    "POST",
                    f"{WORKER}/allegati/link",
                    {"aziendaId": azienda, "key": caricato["objectKey"]},
                    token,
                )
                if stato != 200 or not link.get("url"):
                    errori.append(f"link allegato: {stato} {link}")
                else:
                    req = urllib.request.Request(
                        link["url"], headers={"User-Agent": "Closer-E2E/1.0"}
                    )
                    with urllib.request.urlopen(req, timeout=20) as r:
                        if r.read() != contenuto:
                            errori.append("contenuto allegato diverso")
                stato, _ = call(
                    "DELETE",
                    f"{WORKER}/allegati",
                    {
                        "aziendaId": azienda,
                        "id": caricato["id"],
                        "key": caricato["objectKey"],
                    },
                    token,
                )
                if stato != 200:
                    errori.append(f"delete allegato: {stato}")
        except Exception as e:
            errori.append(f"allegato E2E: {e}")

        # Promemoria: registrazione e annullamento nel KV.
        stato, dati = call(
            "POST",
            f"{WORKER}/promemoria",
            {
                "aziendaId": azienda,
                "appuntamentoId": "app-e2e-promemoria",
                "utenteUids": [uid],
                "occorrenze": [
                    {
                        "dueAt": time.strftime(
                            "%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 3600)
                        ),
                        "testo": "Promemoria E2E",
                    }
                ],
            },
            token,
        )
        if stato != 200 or dati.get("creati", 0) < 1:
            errori.append(f"registrazione promemoria: {stato} {dati}")
        stato, _ = call(
            "POST",
            f"{WORKER}/promemoria/annulla",
            {"aziendaId": azienda, "appuntamentoId": "app-e2e-promemoria"},
            token,
        )
        if stato != 200:
            errori.append(f"annullamento promemoria: {stato}")

        # Ripristina la configurazione reale e verifica il server.
        if config_originale and config_originale.get("url"):
            st, dati = call(
                "POST",
                f"{WORKER}/whatsapp/config",
                {
                    "url": config_originale.get("url"),
                    "apiKey": config_originale.get("apiKey"),
                },
                token,
            )
            if st != 200:
                errori.append(f"ripristino config reale: {st} {dati}")
            stato, server = call("GET", f"{WORKER}/whatsapp/status", token=token)
            if stato != 200 or server.get("connected") is not True:
                errori.append(f"server WhatsApp reale non connesso: {stato} {server}")
        else:
            call("DELETE", f"{WORKER}/whatsapp/config", token=token)

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
                if config_originale and config_originale.get("url"):
                    call(
                        "POST",
                        f"{WORKER}/whatsapp/config",
                        {
                            "url": config_originale.get("url"),
                            "apiKey": config_originale.get("apiKey"),
                        },
                        token,
                    )
                azienda = "e2e-wa-" + suffisso
                for percorso in (
                    f"contatti_notifiche/{azienda}_{uid}",
                    f"membri/{azienda}_{uid}",
                    f"aziende/{azienda}",
                    f"utenti/{uid}",
                ):
                    call("DELETE", f"{FIRESTORE}/{percorso}", token=admin)
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
