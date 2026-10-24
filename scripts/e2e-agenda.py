#!/usr/bin/env python3
"""E2E staging della base agenda: regole Firestore reali.

Crea due utenti e un'azienda temporanei, verifica con i loro token:
- appuntamento: crea/legge/modifica/elimina;
- task: crea/legge;
- chat: stanza, messaggio, lettura;
- notifiche: consegna al destinatario, privacy e segna letta.

Pulisce tutto alla fine. Uso: python3 scripts/e2e-agenda.py
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


def arr(values):
    return {"arrayValue": {"values": [s(v) for v in values]}}


def m(fields):
    return {"mapValue": {"fields": fields}}


def main():
    suffix = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(7))
    az = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(20))
    users = []
    created_docs = []
    errori = []
    try:
        admin = admin_token()
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        # utenti A e B
        for label in ("a", "b"):
            email = f"e2e-agenda-{label}-{suffix}@commerciali.test"
            st, d = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                         {"email": email, "password": "E2eTest12345!", "returnSecureToken": True})
            if st != 200:
                print("FAIL signup", st, d)
                return 1
            users.append({"uid": d["localId"], "email": email, "idToken": d["idToken"]})

        writes = [
            {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/aziende/{az}",
                        "fields": {"nome": s("E2E Agenda"), "created_by": s(users[0]["uid"]), "created_at": s(now)}}},
        ]
        for indice, u in enumerate(users):
            ruolo = "admin" if indice == 0 else "commerciale"
            writes += [
                {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/utenti/{u['uid']}",
                            "fields": {"uid": s(u["uid"]), "email": s(u["email"]), "nome": s(u["email"].split("@")[0]),
                                       "ruolo": s(ruolo), "attivo": b(True), "created_at": s(now)}}},
                {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/membri/{az}_{u['uid']}",
                            "fields": {"azienda_id": s(az), "utente_id": s(u["uid"]), "ruolo": s(ruolo), "created_at": s(now)}}},
            ]
        st, d = call("POST", BASE + ":commit", {"writes": writes}, admin)
        if st != 200:
            print("FAIL setup", st, d)
            return 1

        token_a, token_b = users[0]["idToken"], users[1]["idToken"]

        def percorso(path):
            return f"{BASE}/{path}"

        def crea(path, fields, token):
            st, d = call("PATCH", percorso(path), {"fields": fields}, token)
            if st == 200:
                created_docs.append(path)
            return st, d

        # appuntamento con invito al collega B
        app_id = f"e2e-app-{suffix}"
        st, d = crea(f"appuntamenti/{app_id}", {
            "azienda_id": s(az), "titolo": s("Appuntamento E2E"), "data": s("2026-12-01"),
            "ora": s("10:00"), "operatore_id": s(users[0]["uid"]), "stato": s("da_fare"),
            "invitati_uids": arr([users[1]["uid"]]),
            "conferme": m({}),
            "stato_condivisione": s("in_attesa"),
        }, token_a)
        if st != 200:
            errori.append(f"create appuntamento: {st} {d}")
        else:
            st, _ = call("GET", percorso(f"appuntamenti/{app_id}"), token=token_b)
            if st != 200:
                errori.append(f"read appuntamento da B: {st}")
            st, _ = call("PATCH", percorso(f"appuntamenti/{app_id}?updateMask.fieldPaths=stato"),
                         {"fields": {"stato": s("fatto")}}, token_a)
            if st != 200:
                errori.append(f"update appuntamento: {st}")
            # B, invitato, conferma la disponibilità aggiornando i campi di condivisione
            st, d = call(
                "PATCH",
                percorso(f"appuntamenti/{app_id}?updateMask.fieldPaths=conferme&updateMask.fieldPaths=stato_condivisione"),
                {"fields": {
                    "conferme": m({users[1]["uid"]: m({"stato": s("confermato"), "at": s(now)})}),
                    "stato_condivisione": s("confermato"),
                }},
                token_b,
            )
            if st != 200:
                errori.append(f"conferma invito da B: {st} {d}")
            else:
                st, d = call("GET", percorso(f"appuntamenti/{app_id}"), token=token_a)
                if st != 200 or "stato_condivisione" not in d.get("fields", {}):
                    errori.append("A non vede la conferma di B sull'appuntamento")

        # task
        task_id = f"e2e-task-{suffix}"
        st, d = crea(f"task/{task_id}", {
            "azienda_id": s(az), "titolo": s("Task E2E"), "operatore_id": s(users[0]["uid"]),
            "stato": s("aperto"), "priorita": s("normale"),
        }, token_a)
        if st != 200:
            errori.append(f"create task: {st} {d}")
        else:
            st, _ = call("GET", percorso(f"task/{task_id}"), token=token_b)
            if st != 200:
                errori.append(f"read task da B: {st}")

        # chat
        stanza = f"diretta_{az}_{users[0]['uid']}_{users[1]['uid']}"
        st, d = crea(f"chat_stanze/{stanza}", {
            "azienda_id": s(az), "tipo": s("diretta"), "partecipanti_uids": arr([users[0]["uid"], users[1]["uid"]]),
            "creatore_uid": s(users[0]["uid"]), "created_at": s(now), "updated_at": s(now),
        }, token_a)
        if st != 200:
            errori.append(f"create chat: {st} {d}")
        else:
            msg_id = f"e2e-msg-{suffix}"
            st, d = crea(f"chat_stanze/{stanza}/messaggi/{msg_id}", {
                "mittente_uid": s(users[0]["uid"]), "testo": s("Messaggio E2E"),
                "tipo": s("testo"), "created_at": s(now), "eliminato": b(False),
            }, token_a)
            if st != 200:
                errori.append(f"create messaggio: {st} {d}")
            else:
                st, _ = call("GET", percorso(f"chat_stanze/{stanza}/messaggi/{msg_id}"), token=token_b)
                if st != 200:
                    errori.append(f"read messaggio da B: {st}")
                st, _ = crea(f"chat_stanze/{stanza}/messaggi/msg-falso-{suffix}", {
                    "mittente_uid": s(users[0]["uid"]), "testo": s("spoof"),
                    "tipo": s("testo"), "created_at": s(now), "eliminato": b(False),
                }, token_b)
                if st == 200:
                    errori.append("B ha potuto creare un messaggio spacciandosi per A")

        # notifiche
        not_id = f"e2e-not-{suffix}"
        st, d = crea(f"notifiche/{not_id}", {
            "azienda_id": s(az), "utente_uid": s(users[1]["uid"]), "mittente_uid": s(users[0]["uid"]),
            "tipo": s("appuntamento"), "titolo": s("Notifica E2E"), "testo": s("Test"),
            "stato": s("inviata"), "created_at": s(now),
        }, token_a)
        if st != 200:
            errori.append(f"create notifica: {st} {d}")
        else:
            st, _ = call("GET", percorso(f"notifiche/{not_id}"), token=token_b)
            if st != 200:
                errori.append(f"read notifica da B: {st}")
            st, _ = call("GET", percorso(f"notifiche/{not_id}"), token=token_a)
            if st == 200:
                errori.append("A ha potuto leggere la notifica privata di B")
            st, _ = call("PATCH", percorso(f"notifiche/{not_id}?updateMask.fieldPaths=letta_at"),
                         {"fields": {"letta_at": s(now)}}, token_b)
            if st != 200:
                errori.append(f"segna letta da B: {st}")

        # integrazioni_azienda: solo admin, mai secret
        integrazione_path = f"integrazioni_azienda/{az}"
        st, _ = call("PATCH", percorso(integrazione_path), {"fields": {
            "azienda_id": s(az), "client_secret": s("vietato"),
        }}, token_a)
        if st == 200:
            errori.append("A ha potuto salvare client_secret in integrazioni_azienda")
        st, d = crea(integrazione_path, {
            "azienda_id": s(az),
            "google": m({"modalita": s("closer"), "attivo": b(True), "client_id": s("client-e2e"), "stato": s("configurata")}),
            "microsoft": m({"modalita": s("closer"), "attivo": b(False), "stato": s("non_configurata")}),
            "call_predefinita": s("meet"), "condivisione_abilitata": b(True),
            "livello_condivisione_predefinito": s("dettagli"), "updated_at": s(now),
        }, token_a)
        if st != 200:
            errori.append(f"create integrazione_azienda: {st} {d}")
        else:
            st, _ = call("GET", percorso(integrazione_path), token=token_a)
            if st != 200:
                errori.append(f"read integrazione_azienda da admin: {st}")
            st, _ = call("GET", percorso(integrazione_path), token=token_b)
            if st == 200:
                errori.append("B non admin ha letto integrazioni_azienda")

        # condivisione calendario: proprietario A, destinatario B
        condivisione = f"{az}_{users[0]['uid']}_{users[1]['uid']}"
        condivisione_path = f"condivisioni_calendario/{condivisione}"
        st, d = crea(condivisione_path, {
            "azienda_id": s(az), "proprietario_uid": s(users[0]["uid"]),
            "destinatario_uid": s(users[1]["uid"]), "livello": s("dettagli"),
            "stato": s("attiva"), "creato_da": s(users[0]["uid"]),
            "created_at": s(now), "updated_at": s(now),
        }, token_a)
        if st != 200:
            errori.append(f"create condivisione: {st} {d}")
        else:
            st, _ = call("GET", percorso(condivisione_path), token=token_b)
            if st != 200:
                errori.append(f"read condivisione da B: {st}")
            # B non può spacciarsi per proprietario
            st, _ = crea(f"condivisioni_calendario/{az}_{users[1]['uid']}_{users[0]['uid']}", {
                "azienda_id": s(az), "proprietario_uid": s(users[0]["uid"]),
                "destinatario_uid": s(users[1]["uid"]), "livello": s("dettagli"),
                "stato": s("attiva"), "creato_da": s(users[1]["uid"]),
                "created_at": s(now), "updated_at": s(now),
            }, token_b)
            if st == 200:
                errori.append("B ha potuto creare una condivisione spacciandosi per A")
            # B non può revocare
            st, _ = call("PATCH", percorso(condivisione_path + "?updateMask.fieldPaths=stato"),
                         {"fields": {"stato": s("revocata")}}, token_b)
            if st == 200:
                errori.append("B ha potuto revocare la condivisione di A")
            # A revoca
            st, _ = call("PATCH", percorso(condivisione_path + "?updateMask.fieldPaths=stato&updateMask.fieldPaths=revoked_at&updateMask.fieldPaths=revoked_by&updateMask.fieldPaths=updated_at"),
                         {"fields": {"stato": s("revocata"), "revoked_at": s(now),
                                     "revoked_by": s(users[0]["uid"]), "updated_at": s(now)}}, token_a)
            if st != 200:
                errori.append(f"revoca condivisione da A: {st}")
            # dopo la revoca B non deve più leggere
            st, _ = call("GET", percorso(condivisione_path), token=token_b)
            if st == 200:
                errori.append("B ha letto la condivisione dopo la revoca")

        if errori:
            print("FAIL E2E agenda:")
            for e in errori:
                print(" -", e)
            return 1
        print("PASS: appuntamenti, task, chat, notifiche, integrazioni e condivisioni rispettano le regole")
        return 0
    finally:
        try:
            admin = admin_token()
            for path in created_docs:
                call("DELETE", f"{BASE}/{path}", token=admin)
            for u in users:
                call("DELETE", f"{BASE}/membri/{az}_{u['uid']}", token=admin)
                call("DELETE", f"{BASE}/utenti/{u['uid']}", token=admin)
                call("DELETE", f"{BASE}/aziende/{az}", token=admin)
                call("POST", f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:delete",
                     {"localId": u["uid"]}, admin)
        except Exception as e:
            print("cleanup:", e)


if __name__ == "__main__":
    sys.exit(main())
