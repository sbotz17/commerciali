#!/usr/bin/env python3
"""Blocca il deploy se il registro audit ha aree non PROVATA.

Uso: python3 scripts/controlla-audit.py [--file docs/progetto/test/audit-stato.json]
Esce 0 solo se tutte le aree sono PROVATA.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

STATI_AMMESSI = {"PROVATA", "BLOCCATA", "DA RIFARE", "FALLITA"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--file",
        default="docs/progetto/test/audit-stato.json",
        help="registro audit in JSON",
    )
    args = parser.parse_args()
    percorso = Path(args.file)
    if not percorso.is_file():
        print(f"BLOCCATO: registro audit assente ({percorso}).", file=sys.stderr)
        return 1
    try:
        dati = json.loads(percorso.read_text())
    except ValueError as errore:
        print(f"BLOCCATO: registro audit illeggibile: {errore}", file=sys.stderr)
        return 1
    aree = dati.get("aree")
    if not isinstance(aree, list) or not aree:
        print("BLOCCATO: registro audit senza aree.", file=sys.stderr)
        return 1

    problemi = []
    for area in aree:
        identificativo = str(area.get("id", "?")).strip()
        stato = str(area.get("stato", "")).strip()
        if stato not in STATI_AMMESSI:
            problemi.append(f"{identificativo}: stato non valido «{stato}»")
        elif stato != "PROVATA":
            problemi.append(f"{identificativo}: {stato}")
    if problemi:
        print("BLOCCATO: audit non chiuso. Aree non PROVATA:", file=sys.stderr)
        for problema in problemi:
            print(f"  - {problema}", file=sys.stderr)
        return 1

    print(f"OK: {len(aree)} aree PROVATA. Deploy consentito.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
