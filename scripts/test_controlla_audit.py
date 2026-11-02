#!/usr/bin/env python3
"""Test del gate audit: deve fallire se un'area non è PROVATA."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("controlla-audit.py")


def esegui(contenuto: str | None) -> int:
    with tempfile.TemporaryDirectory() as cartella:
        percorso = Path(cartella) / "audit.json"
        if contenuto is not None:
            percorso.write_text(contenuto)
        esito = subprocess.run(
            [sys.executable, str(SCRIPT), "--file", str(percorso)],
            capture_output=True,
            text=True,
        )
        return esito.returncode


class GateAuditTest(unittest.TestCase):
    def test_tutte_provate_consente(self):
        dati = {"aree": [{"id": "AU01", "stato": "PROVATA"}]}
        self.assertEqual(esegui(json.dumps(dati)), 0)

    def test_una_da_rifare_blocca(self):
        dati = {"aree": [{"id": "AU01", "stato": "PROVATA"}, {"id": "AU02", "stato": "DA RIFARE"}]}
        self.assertEqual(esegui(json.dumps(dati)), 1)

    def test_bloccata_blocca(self):
        dati = {"aree": [{"id": "AU10", "stato": "BLOCCATA"}]}
        self.assertEqual(esegui(json.dumps(dati)), 1)

    def test_fallita_blocca(self):
        dati = {"aree": [{"id": "AU05", "stato": "FALLITA"}]}
        self.assertEqual(esegui(json.dumps(dati)), 1)

    def test_stato_inventato_blocca(self):
        dati = {"aree": [{"id": "AU01", "stato": "OK"}]}
        self.assertEqual(esegui(json.dumps(dati)), 1)

    def test_file_assente_blocca(self):
        self.assertEqual(esegui(None), 1)

    def test_senza_aree_blocca(self):
        self.assertEqual(esegui(json.dumps({"aree": []})), 1)


if __name__ == "__main__":
    unittest.main()
