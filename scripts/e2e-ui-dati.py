#!/usr/bin/env python3
"""Prepara e pulisce un utente di prova per l'E2E UI su staging.

Uso:
  python3 scripts/e2e-ui-dati.py setup    # crea utente/azienda, stampa il file di stato
  python3 scripts/e2e-ui-dati.py cleanup  # elimina tutto

Il file di stato contiene email/password solo per la prova locale e non va
committato (viene creato fuori dal repository).
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
from pathlib import Path

API_KEY = "AIzaSyC1u1OVQxcgHXoKx_oWq_9Rv_YUqW43da4"
PROJECT = "commerciali-app"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
# Ogni esecuzione usa un file di stato suo, salvo E2E_STATO esplicito.
# Serve a non far cancellare l'utente di una sessione da un cleanup di un'altra.
BASE_STATO = Path("/private/var/folders/7y/_z37qnm16b73jbqgc5kysdvw0000gn/T/opencode")


def percorso_stato(suffisso: str | None = None) -> Path:
    """File di stato della prova.

    Con `E2E_STATO` si usa quel percorso. Altrimenti ogni setup crea il suo file
    (`e2e-ui-<suffisso>.json`), cosi' il cleanup di una sessione non cancella
    l'utente di un'altra. Il cleanup senza suffisso usa il file legacy.
    """
    esplicito = os.environ.get("E2E_STATO")
    if esplicito:
        return Path(esplicito)
    if suffisso:
        return BASE_STATO / f"e2e-ui-{suffisso}.json"
    legacy = BASE_STATO / "e2e-ui-legacy.json"
    vecchio = BASE_STATO / "e2e-ui.json"
    return legacy if legacy.exists() else vecchio
PASSWORD = "E2eTest12345!"


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


def i(v):
    return {"integerValue": str(v)}


def setup():
    suffix = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    email = f"e2e-ui-{suffix}@commerciali.test"
    uid = None
    az = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(20))
    try:
        admin = admin_token()
        st, d = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                     {"email": email, "password": PASSWORD, "returnSecureToken": True})
        if st != 200:
            print("signup:", st, d)
            return 1
        uid = d["localId"]
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        oggi = time.strftime("%Y-%m-%d", time.gmtime())

        writes = []

        def w(path, fields):
            writes.append({"update": {
                "name": f"projects/{PROJECT}/databases/(default)/documents/{path}",
                "fields": fields,
            }})

        w(f"utenti/{uid}", {
            "uid": s(uid), "email": s(email), "username": s("e2e"), "nome": s("Utente E2E"),
            "ruolo": s("admin"), "attivo": b(True), "super_admin": b(False), "created_at": s(now),
        })
        w(f"aziende/{az}", {"nome": s("E2E UI Azienda"), "created_by": s(uid), "created_at": s(now)})
        w(f"membri/{az}_{uid}", {
            "azienda_id": s(az), "utente_id": s(uid), "ruolo": s("admin"), "created_at": s(now),
        })
        w(f"licenze/{az}", {
            "azienda_id": s(az), "piano": s("trial"), "stato": s("attiva"),
            "data_inizio": s(oggi), "data_fine": {"nullValue": None},
            "max_utenti": i(5), "max_preventivi": i(50), "updated_at": s(now),
        })
        for chiave, nome, descrizione, sconto, permessi in [
            ("admin", "Amministratore", "Accesso completo", 100,
             {"dashboard": "entrambi", "clienti": "entrambi", "listino": "entrambi",
              "preventivi_tutti": "entrambi", "gestione_utenti": "entrambi",
              "gestione_ruoli": "entrambi", "impostazioni": "entrambi", "bandi": "entrambi"}),
            ("commerciale", "Commerciale", "Accesso operativo", 20,
             {"dashboard": "entrambi", "clienti": "entrambi", "listino": "lettura",
              "preventivi_propri": "entrambi", "bandi": "lettura"}),
        ]:
            w(f"ruoli/{az}_{chiave}", {
                "azienda_id": s(az), "nome": s(nome), "chiave": s(chiave),
                "descrizione": s(descrizione), "sconto_max": i(sconto),
                "sistema": b(True), "permessi": {"mapValue": {"fields": {
                    k: s(v) for k, v in permessi.items()
                }}},
            })
        w(f"categorie/{az}_generale", {
            "azienda_id": s(az), "nome": s("Generale"), "ordine": i(1), "created_at": s(now),
        })

        st, d = call("POST", BASE + ":commit", {"writes": writes}, admin)
        if st != 200:
            print("setup:", st, d)
            return 1

        stato = percorso_stato(suffix)
        stato.parent.mkdir(parents=True, exist_ok=True)
        stato.write_text(json.dumps({
            "uid": uid, "azienda": az, "email": email, "password": PASSWORD,
        }, indent=2))
        print("PRONTO", email, az)
        print("stato:", stato)
        return 0
    except Exception as e:
        print("ERRORE setup:", e)
        return 1


def cleanup():
    stato = percorso_stato()
    if not stato.exists():
        print("nessuno stato da pulire")
        candidati = sorted(BASE_STATO.glob("e2e-ui-*.json"))
        if candidati:
            print("file di stato disponibili (usa E2E_STATO=<file>):")
            for c in candidati:
                print(" -", c)
        return 0
    dati = json.loads(stato.read_text())
    admin = admin_token()
    uid, az = dati["uid"], dati["azienda"]
    # Elimina tutti i documenti delle collezioni per azienda creati dalla prova.
    for collezione in ["clienti", "preventivi", "giro_visite", "prodotti",
                       "categorie", "ruoli"]:
        q = {"structuredQuery": {
            "from": [{"collectionId": collezione}],
            "where": {"fieldFilter": {
                "field": {"fieldPath": "azienda_id"}, "op": "EQUAL",
                "value": {"stringValue": az},
            }},
        }}
        st, d = call("POST", BASE + ":runQuery", q, admin)
        if st == 200 and isinstance(d, list):
            for riga in d:
                nome = riga.get("document", {}).get("name")
                if nome:
                    call("DELETE", f"https://firestore.googleapis.com/v1/{nome}", token=admin)
    for path in [f"contatori/preventivi_{az}",
                 f"membri/{az}_{uid}", f"aziende/{az}", f"licenze/{az}",
                 f"utenti/{uid}"]:
        call("DELETE", f"{BASE}/{path}", token=admin)
    call("POST", f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:delete",
         {"localId": uid}, admin)
    stato.unlink(missing_ok=True)
    print("PULITO")
    return 0


if __name__ == "__main__":
    azione = sys.argv[1] if len(sys.argv) > 1 else "setup"
    sys.exit(setup() if azione == "setup" else cleanup())
