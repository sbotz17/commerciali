#!/usr/bin/env python3
"""Blocchi funzionali della squadra: un solo lavoro attivo per blocco.

Il registro vive dentro la cartella Git comune del repository, quindi è
condiviso da tutte le worktree e da tutte le sessioni dello stesso progetto.
Non contiene dati del prodotto e non viene committato.

Uso:
  python3 scripts/blocco-squadra.py stato
  python3 scripts/blocco-squadra.py occupa <blocco> --richiesta "..." [--sessione "..."]
  python3 scripts/blocco-squadra.py rilascia <blocco> --motivo "..."
  python3 scripts/blocco-squadra.py coda <blocco> --richiesta "..." [--sessione "..."]
  python3 scripts/blocco-squadra.py coda-lista <blocco>

Esce con 2 quando il blocco è già occupato: in quel caso la richiesta NON
parte e va messa in coda.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import socket
import string
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

SCADENZA_ORE = 24
NOME_VALIDO = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")


def cartella_git() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--git-common-dir"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("blocco-squadra: non sono in un repository Git.", file=sys.stderr)
        raise SystemExit(1)
    return Path(out).resolve()


def base() -> Path:
    return cartella_git() / "squadra-blocchi"


def controlla_blocco(blocco: str) -> str:
    if not NOME_VALIDO.match(blocco):
        print(
            "blocco-squadra: nome blocco non valido (minuscole, numeri e trattini, max 64).",
            file=sys.stderr,
        )
        raise SystemExit(1)
    return blocco


def cartella_blocco(blocco: str) -> Path:
    return base() / controlla_blocco(blocco)


def percorso_owner(blocco: str) -> Path:
    return cartella_blocco(blocco) / "owner.json"


def adesso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def leggi_json(percorso: Path) -> dict | None:
    try:
        return json.loads(percorso.read_text())
    except (OSError, ValueError):
        return None


def eta_ore(istante: str | None) -> float | None:
    if not istante:
        return None
    try:
        quando = datetime.fromisoformat(istante)
        if quando.tzinfo is None:
            quando = quando.replace(tzinfo=timezone.utc)
        return (datetime.now(timezone.utc) - quando).total_seconds() / 3600
    except ValueError:
        return None


def descrivi_owner(owner: dict, con_stato: bool = True) -> str:
    ore = eta_ore(owner.get("iniziato_at"))
    quando = owner.get("iniziato_at", "?")
    if ore is not None:
        quando = f"{quando} ({ore:.1f} ore fa)"
    stato = "SCADUTO" if ore is not None and ore >= SCADENZA_ORE else "in corso"
    prefisso = f"{stato}: " if con_stato else ""
    return (
        f"{prefisso}richiesta «{owner.get('richiesta', '?')}» "
        f"· sessione {owner.get('sessione', '?')} · iniziata {quando}"
    )


def voci_coda(blocco: str) -> list[Path]:
    cartella = cartella_blocco(blocco) / "coda"
    if not cartella.is_dir():
        return []
    return sorted(cartella.glob("*.json"))


def cmd_stato(_: argparse.Namespace) -> int:
    radice = base()
    if not radice.is_dir():
        print("Nessun blocco occupato.")
        return 0
    blocchi = sorted(p for p in radice.iterdir() if p.is_dir())
    if not blocchi:
        print("Nessun blocco occupato.")
        return 0
    for cartella in blocchi:
        blocco = cartella.name
        owner = leggi_json(cartella / "owner.json")
        coda = voci_coda(blocco)
        if owner:
            print(f"[{blocco}] {descrivi_owner(owner)} · coda: {len(coda)}")
            ore = eta_ore(owner.get("iniziato_at"))
            if ore is not None and ore >= SCADENZA_ORE:
                print(
                    "  suggerimento: verifica che la sessione non sia più attiva, poi "
                    "`rilascia <blocco> --motivo ... --forza` (solo dopo la prova)."
                )
        else:
            print(f"[{blocco}] libero · coda: {len(coda)}")
    return 0


def cmd_occupa(args: argparse.Namespace) -> int:
    sessione = args.sessione or sessione_predefinita()
    coda = voci_coda(args.blocco)
    if coda and not args.forza:
        prima = leggi_json(coda[0]) or {}
        if prima.get("sessione") != sessione:
            print(
                f"CODA [{args.blocco}]: davanti a te c'è «{prima.get('richiesta', '?')}» "
                f"(sessione {prima.get('sessione', '?')}). Mettiti in coda e aspetta il tuo turno."
            )
            return 2
    dest = percorso_owner(args.blocco)
    dest.parent.mkdir(parents=True, exist_ok=True)
    owner = {
        "blocco": args.blocco,
        "richiesta": args.richiesta,
        "sessione": sessione,
        "iniziato_at": adesso(),
        "cartella": os.getcwd(),
        "pid": os.getpid(),
        "host": socket.gethostname(),
    }
    try:
        fd = os.open(dest, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    except FileExistsError:
        esistente = leggi_json(dest) or {}
        print(f"OCCUPATO [{args.blocco}] {descrivi_owner(esistente)}")
        print("La richiesta NON parte: mettila in coda con `coda` e avvisa Andrea.")
        return 2
    with os.fdopen(fd, "w") as file:
        json.dump(owner, file, ensure_ascii=False, indent=2)
        file.write("\n")
    if coda:
        prima = leggi_json(coda[0]) or {}
        if prima.get("sessione") == sessione:
            coda[0].unlink()
    print(f"OCCUPATO [{args.blocco}] da {owner['sessione']} · richiesta «{args.richiesta}»")
    return 0


def cmd_rilascia(args: argparse.Namespace) -> int:
    dest = percorso_owner(args.blocco)
    sessione = args.sessione or sessione_predefinita()
    if not dest.exists():
        print(f"LIBERO [{args.blocco}] (nessun proprietario)")
    else:
        owner = leggi_json(dest) or {}
        if owner.get("sessione") != sessione and not args.forza:
            print(
                f"NON LIBERATO [{args.blocco}]: è di {owner.get('sessione', '?')}, non di {sessione}. "
                "Serve la sessione proprietaria o --forza (solo con prova che non c'è lavoro in corso)."
            )
            return 2
        dest.unlink()
        print(f"LIBERATO [{args.blocco}] · motivo: {args.motivo}")
        if owner:
            print(f"  chiude: {descrivi_owner(owner, con_stato=False)}")
    coda = voci_coda(args.blocco)
    if coda:
        prossimo = leggi_json(coda[0]) or {}
        print(
            f"  coda: {len(coda)} richieste; la prima è «{prossimo.get('richiesta', '?')}» "
            f"(sessione {prossimo.get('sessione', '?')})."
        )
    return 0


def cmd_coda(args: argparse.Namespace) -> int:
    cartella = cartella_blocco(args.blocco) / "coda"
    cartella.mkdir(parents=True, exist_ok=True)
    suffisso = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(6))
    nome = f"{time.time_ns()}-{suffisso}.json"
    voce = {
        "blocco": args.blocco,
        "richiesta": args.richiesta,
        "sessione": args.sessione or sessione_predefinita(),
        "messo_in_coda_at": adesso(),
    }
    percorso = cartella / nome
    percorso.write_text(json.dumps(voce, ensure_ascii=False, indent=2) + "\n")
    posizione = voci_coda(args.blocco).index(percorso) + 1
    print(f"IN CODA [{args.blocco}] posizione {posizione} · richiesta «{args.richiesta}»")
    if not percorso_owner(args.blocco).exists():
        print("  nota: il blocco ora è libero; puoi occuparlo con `occupa`.")
    return 0


def cmd_coda_rimuovi(args: argparse.Namespace) -> int:
    voci = voci_coda(args.blocco)
    if not voci:
        print(f"Nessuna richiesta in coda per [{args.blocco}].")
        return 0
    if args.indice < 1 or args.indice > len(voci):
        print(f"Indice fuori scala: la coda ha {len(voci)} voci.")
        return 1
    percorso = voci[args.indice - 1]
    voce = leggi_json(percorso) or {}
    sessione = args.sessione or sessione_predefinita()
    if voce.get("sessione") != sessione and not args.forza:
        print(
            f"NON RIMOSSA: la voce è di {voce.get('sessione', '?')}, non di {sessione}. "
            "Serve la sessione proprietaria o --forza."
        )
        return 2
    percorso.unlink()
    print(f"RIMOSSA dalla coda [{args.blocco}] posizione {args.indice}: «{voce.get('richiesta', '?')}»")
    return 0


def cmd_coda_lista(args: argparse.Namespace) -> int:
    voci = voci_coda(args.blocco)
    if not voci:
        print(f"Nessuna richiesta in coda per [{args.blocco}].")
        return 0
    for indice, percorso in enumerate(voci, start=1):
        voce = leggi_json(percorso) or {}
        print(
            f"{indice}. «{voce.get('richiesta', '?')}» · sessione {voce.get('sessione', '?')} "
            f"· {voce.get('messo_in_coda_at', '?')}"
        )
    return 0


def sessione_predefinita() -> str:
    return os.environ.get("OPENCODE_SESSION") or f"{socket.gethostname()}-{os.getpid()}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Blocchi funzionali della squadra")
    comandi = parser.add_subparsers(dest="comando", required=True)

    comandi.add_parser("stato", help="mostra blocchi occupati e code")

    occupa = comandi.add_parser("occupa", help="occupa un blocco")
    occupa.add_argument("blocco")
    occupa.add_argument("--richiesta", required=True)
    occupa.add_argument("--sessione")
    occupa.add_argument("--forza", action="store_true", help="solo coordinatore/Andrea, con motivo")

    rilascia = comandi.add_parser("rilascia", help="libera un blocco")
    rilascia.add_argument("blocco")
    rilascia.add_argument("--motivo", required=True)
    rilascia.add_argument("--sessione")
    rilascia.add_argument("--forza", action="store_true", help="solo con prova che non c'è lavoro in corso")

    coda = comandi.add_parser("coda", help="mette una richiesta in coda")
    coda.add_argument("blocco")
    coda.add_argument("--richiesta", required=True)
    coda.add_argument("--sessione")

    coda_lista = comandi.add_parser("coda-lista", help="mostra la coda di un blocco")
    coda_lista.add_argument("blocco")

    coda_rimuovi = comandi.add_parser("coda-rimuovi", help="toglie una voce dalla coda")
    coda_rimuovi.add_argument("blocco")
    coda_rimuovi.add_argument("--indice", type=int, required=True)
    coda_rimuovi.add_argument("--sessione")
    coda_rimuovi.add_argument("--forza", action="store_true")

    args = parser.parse_args()
    azioni = {
        "stato": cmd_stato,
        "occupa": cmd_occupa,
        "rilascia": cmd_rilascia,
        "coda": cmd_coda,
        "coda-lista": cmd_coda_lista,
        "coda-rimuovi": cmd_coda_rimuovi,
    }
    return azioni[args.comando](args)


if __name__ == "__main__":
    raise SystemExit(main())
